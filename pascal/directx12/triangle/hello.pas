program hello;

{$mode delphi}

uses
  Windows, Messages, SysUtils;

const
  WIDTH  = 640;
  HEIGHT = 480;
  FRAMES = 2;

// ===========================================
// DirectX 12 Constants
// ===========================================
const
  DXGI_FORMAT_UNKNOWN            = 0;
  DXGI_FORMAT_R32G32B32_FLOAT    = 6;
  DXGI_FORMAT_R32G32B32A32_FLOAT = 2;
  DXGI_FORMAT_R8G8B8A8_UNORM     = 28;

  D3D_FEATURE_LEVEL_12_0 = $c000;

  D3D12_COMMAND_LIST_TYPE_DIRECT = 0;
  D3D12_COMMAND_QUEUE_FLAG_NONE  = 0;

  D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0;
  D3D12_DESCRIPTOR_HEAP_TYPE_SAMPLER = 1;
  D3D12_DESCRIPTOR_HEAP_TYPE_RTV  = 2;
  D3D12_DESCRIPTOR_HEAP_TYPE_DSV = 3;
  D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0;

  D3D12_HEAP_TYPE_UPLOAD            = 2;
  D3D12_CPU_PAGE_PROPERTY_UNKNOWN   = 0;
  D3D12_MEMORY_POOL_UNKNOWN         = 0;

  D3D12_RESOURCE_DIMENSION_BUFFER   = 1;
  D3D12_RESOURCE_STATE_PRESENT      = 0;
  D3D12_RESOURCE_STATE_RENDER_TARGET = $4;
  D3D12_RESOURCE_STATE_GENERIC_READ = $1 or $2 or $40 or $80 or $200 or $800;

  D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0;
  D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = $FFFFFFFF;

  D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = $1;

  D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA = 0;

  D3D12_FILL_MODE_SOLID = 3;
  D3D12_CULL_MODE_NONE  = 1;  // Changed from BACK to NONE to avoid culling issues
  D3D12_CULL_MODE_BACK  = 3;

  D3D12_DEFAULT_DEPTH_BIAS       = 0;
  D3D12_DEFAULT_DEPTH_BIAS_CLAMP = 0.0;

  D3D12_BLEND_OP_ADD     = 1;
  D3D12_LOGIC_OP_NOOP    = 5;
  D3D12_COLOR_WRITE_ENABLE_ALL = 15;

  D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3;
  D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST    = 4;

  D3D12_FENCE_FLAG_NONE = 0;

  D3D_ROOT_SIGNATURE_VERSION_1 = 1;

  DXGI_USAGE_RENDER_TARGET_OUTPUT = $20;
  DXGI_SWAP_EFFECT_FLIP_DISCARD   = 4;

  // GUIDs
  IID_IDXGIFactory4: TGUID       = '{1bc6ea02-ef36-464f-bf0c-21ca39e5168a}';
  IID_ID3D12Device: TGUID        = '{189819f1-1db6-4b57-be54-1821339b85f7}';
  IID_ID3D12CommandQueue: TGUID  = '{0ec870a6-5d7e-4c22-8cfc-5baae07616ed}';
  IID_IDXGISwapChain3: TGUID     = '{94d99bdb-f1f8-4ab0-b236-7da0170edab1}';
  IID_ID3D12DescriptorHeap: TGUID = '{8efb471d-616c-4f49-90f7-127bb763fa51}';
  IID_ID3D12Resource: TGUID      = '{696442be-a72e-4059-bc79-5b5c98040fad}';
  IID_ID3D12CommandAllocator: TGUID = '{6102dee4-af59-4b09-b999-b44d73f09b24}';
  IID_ID3D12GraphicsCommandList: TGUID = '{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}';
  IID_ID3D12PipelineState: TGUID = '{765a30f3-f624-4c6f-a828-ace948622445}';
  IID_ID3D12RootSignature: TGUID = '{c54a6b66-72df-4ee8-8be5-a946a1429214}';
  IID_ID3D12Fence: TGUID         = '{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}';

type
  // ===========================================
  // Basic Structures
  // ===========================================
  PPointer = ^Pointer;

  VERTEX = record
    position: array[0..2] of Single;
    color: array[0..3] of Single;
  end;

  DXGI_RATIONAL = record
    Numerator: UINT;
    Denominator: UINT;
  end;

  DXGI_MODE_DESC = record
    Width: UINT;
    Height: UINT;
    RefreshRate: DXGI_RATIONAL;
    Format: UINT;
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

  D3D12_COMMAND_QUEUE_DESC = record
    Type_: UINT;
    Priority: Integer;
    Flags: UINT;
    NodeMask: UINT;
  end;

  D3D12_DESCRIPTOR_HEAP_DESC = record
    Type_: UINT;
    NumDescriptors: UINT;
    Flags: UINT;
    NodeMask: UINT;
  end;

  D3D12_CPU_DESCRIPTOR_HANDLE = record
    ptr: SIZE_T;
  end;
  PD3D12_CPU_DESCRIPTOR_HANDLE = ^D3D12_CPU_DESCRIPTOR_HANDLE;
  
  D3D12_GPU_DESCRIPTOR_HANDLE = record
    ptr: UINT64;
  end;

  D3D12_HEAP_PROPERTIES = record
    Type_: UINT;
    CPUPageProperty: UINT;
    MemoryPoolPreference: UINT;
    CreationNodeMask: UINT;
    VisibleNodeMask: UINT;
  end;

  D3D12_RESOURCE_DESC = record
    Dimension: UINT;
    Alignment: UINT64;
    Width: UINT64;
    Height: UINT;
    DepthOrArraySize: WORD;
    MipLevels: WORD;
    Format: UINT;
    SampleDesc: DXGI_SAMPLE_DESC;
    Layout: UINT;
    Flags: UINT;
  end;

  D3D12_RESOURCE_TRANSITION_BARRIER = record
    pResource: Pointer;
    Subresource: UINT;
    StateBefore: UINT;
    StateAfter: UINT;
  end;

  D3D12_RESOURCE_BARRIER = record
    Type_: UINT;
    Flags: UINT;
    Transition: D3D12_RESOURCE_TRANSITION_BARRIER;
  end;

  D3D12_VIEWPORT = record
    TopLeftX: Single;
    TopLeftY: Single;
    Width: Single;
    Height: Single;
    MinDepth: Single;
    MaxDepth: Single;
  end;

  D3D12_RECT = record
    left: LONG;
    top: LONG;
    right: LONG;
    bottom: LONG;
  end;

  D3D12_VERTEX_BUFFER_VIEW = record
    BufferLocation: UINT64;
    SizeInBytes: UINT;
    StrideInBytes: UINT;
  end;

  D3D12_INPUT_ELEMENT_DESC = record
    SemanticName: PAnsiChar;
    SemanticIndex: UINT;
    Format: UINT;
    InputSlot: UINT;
    AlignedByteOffset: UINT;
    InputSlotClass: UINT;
    InstanceDataStepRate: UINT;
  end;
  PD3D12_INPUT_ELEMENT_DESC = ^D3D12_INPUT_ELEMENT_DESC;

  D3D12_INPUT_LAYOUT_DESC = record
    pInputElementDescs: PD3D12_INPUT_ELEMENT_DESC;
    NumElements: UINT;
  end;

  D3D12_SHADER_BYTECODE = record
    pShaderBytecode: Pointer;
    BytecodeLength: SIZE_T;
  end;

  D3D12_RASTERIZER_DESC = record
    FillMode: UINT;
    CullMode: UINT;
    FrontCounterClockwise: BOOL;
    DepthBias: Integer;
    DepthBiasClamp: Single;
    SlopeScaledDepthBias: Single;
    DepthClipEnable: BOOL;
    MultisampleEnable: BOOL;
    AntialiasedLineEnable: BOOL;
    ForcedSampleCount: UINT;
    ConservativeRaster: UINT;
  end;

  D3D12_RENDER_TARGET_BLEND_DESC = record
    BlendEnable: BOOL;
    LogicOpEnable: BOOL;
    SrcBlend: UINT;
    DestBlend: UINT;
    BlendOp: UINT;
    SrcBlendAlpha: UINT;
    DestBlendAlpha: UINT;
    BlendOpAlpha: UINT;
    LogicOp: UINT;
    RenderTargetWriteMask: BYTE;
  end;

  D3D12_BLEND_DESC = record
    AlphaToCoverageEnable: BOOL;
    IndependentBlendEnable: BOOL;
    RenderTarget: array[0..7] of D3D12_RENDER_TARGET_BLEND_DESC;
  end;

  D3D12_DEPTH_STENCILOP_DESC = record
    StencilFailOp: UINT;
    StencilDepthFailOp: UINT;
    StencilPassOp: UINT;
    StencilFunc: UINT;
  end;

  D3D12_DEPTH_STENCIL_DESC = record
    DepthEnable: BOOL;
    DepthWriteMask: UINT;
    DepthFunc: UINT;
    StencilEnable: BOOL;
    StencilReadMask: BYTE;
    StencilWriteMask: BYTE;
    FrontFace: D3D12_DEPTH_STENCILOP_DESC;
    BackFace: D3D12_DEPTH_STENCILOP_DESC;
  end;

  D3D12_STREAM_OUTPUT_DESC = record
    pSODeclaration: Pointer;
    NumEntries: UINT;
    pBufferStrides: PUINT;
    NumStrides: UINT;
    RasterizedStream: UINT;
  end;

  D3D12_CACHED_PIPELINE_STATE = record
    pCachedBlob: Pointer;
    CachedBlobSizeInBytes: SIZE_T;
  end;

  D3D12_GRAPHICS_PIPELINE_STATE_DESC = record
    pRootSignature: Pointer;
    VS: D3D12_SHADER_BYTECODE;
    PS: D3D12_SHADER_BYTECODE;
    DS: D3D12_SHADER_BYTECODE;
    HS: D3D12_SHADER_BYTECODE;
    GS: D3D12_SHADER_BYTECODE;
    StreamOutput: D3D12_STREAM_OUTPUT_DESC;
    BlendState: D3D12_BLEND_DESC;
    SampleMask: UINT;
    RasterizerState: D3D12_RASTERIZER_DESC;
    DepthStencilState: D3D12_DEPTH_STENCIL_DESC;
    InputLayout: D3D12_INPUT_LAYOUT_DESC;
    IBStripCutValue: UINT;
    PrimitiveTopologyType: UINT;
    NumRenderTargets: UINT;
    RTVFormats: array[0..7] of UINT;
    DSVFormat: UINT;
    SampleDesc: DXGI_SAMPLE_DESC;
    NodeMask: UINT;
    CachedPSO: D3D12_CACHED_PIPELINE_STATE;
    Flags: UINT;
  end;

  D3D12_ROOT_SIGNATURE_DESC = record
    NumParameters: UINT;
    pParameters: Pointer;
    NumStaticSamplers: UINT;
    pStaticSamplers: Pointer;
    Flags: UINT;
  end;

  // ===========================================
  // COM Interface VTables
  // ===========================================

  // ID3DBlob
  ID3DBlobVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetBufferPointer: function(Self: Pointer): Pointer; stdcall;
    GetBufferSize: function(Self: Pointer): SIZE_T; stdcall;
  end;
  PID3DBlobVtbl = ^ID3DBlobVtbl;
  ID3DBlob = record lpVtbl: PID3DBlobVtbl; end;
  PID3DBlob = ^ID3DBlob;

  // IDXGIFactory4
  IDXGIFactory4Vtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    SetPrivateData: function(Self: Pointer; const Name: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const Name: TGUID; pUnknown: Pointer): HRESULT; stdcall;
    GetPrivateData: function(Self: Pointer; const Name: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    GetParent: function(Self: Pointer; const riid: TGUID; out ppParent): HRESULT; stdcall;
    EnumAdapters: function(Self: Pointer; Adapter: UINT; out ppAdapter): HRESULT; stdcall;
    MakeWindowAssociation: function(Self: Pointer; WindowHandle: HWND; Flags: UINT): HRESULT; stdcall;
    GetWindowAssociation: function(Self: Pointer; out pWindowHandle: HWND): HRESULT; stdcall;
    CreateSwapChain: function(Self: Pointer; pDevice: Pointer; pDesc: Pointer; out ppSwapChain): HRESULT; stdcall;
    CreateSoftwareAdapter: function(Self: Pointer; Module: HMODULE; out ppAdapter): HRESULT; stdcall;
    EnumAdapters1: function(Self: Pointer; Adapter: UINT; out ppAdapter): HRESULT; stdcall;
    IsCurrent: function(Self: Pointer): BOOL; stdcall;
    IsWindowedStereoEnabled: function(Self: Pointer): BOOL; stdcall;
    CreateSwapChainForHwnd: pointer;
    CreateSwapChainForCoreWindow: pointer;
    GetSharedResourceAdapterLuid: pointer;
    RegisterStereoStatusWindow: pointer;
    RegisterStereoStatusEvent: pointer;
    UnregisterStereoStatus: pointer;
    RegisterOcclusionStatusWindow: pointer;
    RegisterOcclusionStatusEvent: pointer;
    UnregisterOcclusionStatus: pointer;
    CreateSwapChainForComposition: pointer;
    GetCreationFlags: pointer;
    EnumAdapterByLuid: pointer;
    EnumWarpAdapter: pointer;
  end;
  PIDXGIFactory4Vtbl = ^IDXGIFactory4Vtbl;
  IDXGIFactory4 = record lpVtbl: PIDXGIFactory4Vtbl; end;
  PIDXGIFactory4 = ^IDXGIFactory4;

  // IDXGISwapChain
  IDXGISwapChainVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    SetPrivateData: function(Self: Pointer; const Name: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const Name: TGUID; pUnknown: Pointer): HRESULT; stdcall;
    GetPrivateData: function(Self: Pointer; const Name: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    GetParent: function(Self: Pointer; const riid: TGUID; out ppParent): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppDevice): HRESULT; stdcall;
    Present: function(Self: Pointer; SyncInterval: UINT; Flags: UINT): HRESULT; stdcall;
    GetBuffer: function(Self: Pointer; Buffer: UINT; const riid: TGUID; out ppSurface): HRESULT; stdcall;
  end;
  PIDXGISwapChainVtbl = ^IDXGISwapChainVtbl;
  IDXGISwapChain = record lpVtbl: PIDXGISwapChainVtbl; end;
  PIDXGISwapChain = ^IDXGISwapChain;

  // IDXGISwapChain3
  IDXGISwapChain3Vtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    SetPrivateData: function(Self: Pointer; const Name: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const Name: TGUID; pUnknown: Pointer): HRESULT; stdcall;
    GetPrivateData: function(Self: Pointer; const Name: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    GetParent: function(Self: Pointer; const riid: TGUID; out ppParent): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppDevice): HRESULT; stdcall;
    Present: function(Self: Pointer; SyncInterval: UINT; Flags: UINT): HRESULT; stdcall;
    GetBuffer: function(Self: Pointer; Buffer: UINT; const riid: TGUID; out ppSurface): HRESULT; stdcall;
    SetFullscreenState: function(Self: Pointer; Fullscreen: BOOL; pTarget: Pointer): HRESULT; stdcall;
    GetFullscreenState: function(Self: Pointer; out pFullscreen: BOOL; out ppTarget: Pointer): HRESULT; stdcall;
    GetDesc: function(Self: Pointer; out pDesc: DXGI_SWAP_CHAIN_DESC): HRESULT; stdcall;
    ResizeBuffers: function(Self: Pointer; BufferCount, Width, Height, NewFormat, SwapChainFlags: UINT): HRESULT; stdcall;
    ResizeTarget: function(Self: Pointer; const pNewTargetParameters: DXGI_MODE_DESC): HRESULT; stdcall;
    GetContainingOutput: function(Self: Pointer; out ppOutput: Pointer): HRESULT; stdcall;
    GetFrameStatistics: function(Self: Pointer; out pStats): HRESULT; stdcall;
    GetLastPresentCount: function(Self: Pointer; out pLastPresentCount: UINT): HRESULT; stdcall;
    GetDesc1: pointer;
    GetFullscreenDesc: pointer;
    GetHwnd: pointer;
    GetCoreWindow: pointer;
    Present1: pointer;
    IsTemporaryMonoSupported: pointer;
    GetRestrictToOutput: pointer;
    SetBackgroundColor: pointer;
    GetBackgroundColor: pointer;
    SetRotation: pointer;
    GetRotation: pointer;
    SetSourceSize: pointer;
    GetSourceSize: pointer;
    SetMaximumFrameLatency: pointer;
    GetMaximumFrameLatency: pointer;
    GetFrameLatencyWaitableObject: pointer;
    SetMatrixTransform: pointer;
    GetMatrixTransform: pointer;
    GetCurrentBackBufferIndex: function(Self: Pointer): UINT; stdcall;
    CheckColorSpaceSupport: pointer;
    SetColorSpace1: pointer;
    ResizeBuffers1: pointer;
  end;
  PIDXGISwapChain3Vtbl = ^IDXGISwapChain3Vtbl;
  IDXGISwapChain3 = record lpVtbl: PIDXGISwapChain3Vtbl; end;
  PIDXGISwapChain3 = ^IDXGISwapChain3;

  // ID3D12Device
  ID3D12DeviceVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; var ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetNodeCount: function(Self: Pointer): UINT; stdcall;
    CreateCommandQueue: function(Self: Pointer; const pDesc: D3D12_COMMAND_QUEUE_DESC; const riid: TGUID; var ppCommandQueue: Pointer): HRESULT; stdcall;
    CreateCommandAllocator: function(Self: Pointer; type_: UINT; const riid: TGUID; var ppCommandAllocator: Pointer): HRESULT; stdcall;
    CreateGraphicsPipelineState: function(Self: Pointer; const pDesc: D3D12_GRAPHICS_PIPELINE_STATE_DESC; const riid: TGUID; var ppPipelineState: Pointer): HRESULT; stdcall;
    CreateComputePipelineState: function(Self: Pointer; pDesc: Pointer; const riid: TGUID; var ppPipelineState: Pointer): HRESULT; stdcall;
    CreateCommandList: function(Self: Pointer; nodeMask: UINT; type_: UINT; pCommandAllocator: Pointer; pInitialState: Pointer; const riid: TGUID; var ppCommandList: Pointer): HRESULT; stdcall;
    CheckFeatureSupport: function(Self: Pointer; Feature: UINT; pFeatureSupportData: Pointer; FeatureSupportDataSize: UINT): HRESULT; stdcall;
    CreateDescriptorHeap: function(Self: Pointer; const pDescriptorHeapDesc: D3D12_DESCRIPTOR_HEAP_DESC; const riid: TGUID; var ppvHeap: Pointer): HRESULT; stdcall;
    GetDescriptorHandleIncrementSize: function(Self: Pointer; DescriptorHeapType: UINT): UINT; stdcall;
    CreateRootSignature: function(Self: Pointer; nodeMask: UINT; pBlobWithRootSignature: Pointer; blobLengthInBytes: SIZE_T; const riid: TGUID; var ppvRootSignature: Pointer): HRESULT; stdcall;
    CreateConstantBufferView: procedure(Self: Pointer; pDesc: Pointer; DestDescriptor: SIZE_T); stdcall;
    CreateShaderResourceView: procedure(Self: Pointer; pResource: Pointer; pDesc: Pointer; DestDescriptor: SIZE_T); stdcall;
    CreateUnorderedAccessView: procedure(Self: Pointer; pResource: Pointer; pCounterResource: Pointer; pDesc: Pointer; DestDescriptor: SIZE_T); stdcall;
    CreateRenderTargetView: procedure(Self: Pointer; pResource: Pointer; pDesc: Pointer; DestDescriptor: SIZE_T); stdcall;
    CreateDepthStencilView: procedure(Self: Pointer; pResource: Pointer; pDesc: Pointer; DestDescriptor: SIZE_T); stdcall;
    CreateSampler: procedure(Self: Pointer; pDesc: Pointer; DestDescriptor: SIZE_T); stdcall;
    CopyDescriptors: procedure(Self: Pointer; NumDestDescriptorRanges: UINT; pDestDescriptorRangeStarts: Pointer; pDestDescriptorRangeSizes: PUINT; NumSrcDescriptorRanges: UINT; pSrcDescriptorRangeStarts: Pointer; pSrcDescriptorRangeSizes: PUINT; DescriptorHeapsType: UINT); stdcall;
    CopyDescriptorsSimple: procedure(Self: Pointer; NumDescriptors: UINT; DestDescriptorRangeStart: SIZE_T; SrcDescriptorRangeStart: SIZE_T; DescriptorHeapsType: UINT); stdcall;
    GetResourceAllocationInfo: pointer;
    GetCustomHeapProperties: pointer;
    CreateCommittedResource: function(Self: Pointer; const pHeapProperties: D3D12_HEAP_PROPERTIES; HeapFlags: UINT; const pDesc: D3D12_RESOURCE_DESC; InitialResourceState: UINT; pOptimizedClearValue: Pointer; const riid: TGUID; var ppvResource: Pointer): HRESULT; stdcall;
    CreateHeap: function(Self: Pointer; pDesc: Pointer; const riid: TGUID; var ppvHeap: Pointer): HRESULT; stdcall;
    CreatePlacedResource: function(Self: Pointer; pHeap: Pointer; HeapOffset: UINT64; pDesc: Pointer; InitialState: UINT; pOptimizedClearValue: Pointer; const riid: TGUID; var ppvResource: Pointer): HRESULT; stdcall;
    CreateReservedResource: function(Self: Pointer; pDesc: Pointer; InitialState: UINT; pOptimizedClearValue: Pointer; const riid: TGUID; var ppvResource: Pointer): HRESULT; stdcall;
    CreateSharedHandle: function(Self: Pointer; pObject: Pointer; pAttributes: Pointer; Access: DWORD; Name: PWideChar; out pHandle: THandle): HRESULT; stdcall;
    OpenSharedHandle: function(Self: Pointer; NTHandle: THandle; const riid: TGUID; var ppvObj: Pointer): HRESULT; stdcall;
    OpenSharedHandleByName: function(Self: Pointer; Name: PWideChar; Access: DWORD; out pNTHandle: Pointer): HRESULT; stdcall;
    MakeResident: function(Self: Pointer; NumObjects: UINT; ppObjects: Pointer): HRESULT; stdcall;
    Evict: function(Self: Pointer; NumObjects: UINT; ppObjects: Pointer): HRESULT; stdcall;
    CreateFence: function(Self: Pointer; InitialValue: UINT64; Flags: UINT; const riid: TGUID; var ppFence: Pointer): HRESULT; stdcall;
    GetDeviceRemovedReason: function(Self: Pointer): HRESULT; stdcall;
    GetCopyableFootprints: procedure(Self: Pointer; pResourceDesc: Pointer; FirstSubresource, NumSubresources: UINT; BaseOffset: UINT64; pLayouts, pNumRows: Pointer; pRowSizeInBytes: PUINT64; pTotalBytes: PUINT64); stdcall;
    CreateQueryHeap: function(Self: Pointer; pDesc: Pointer; const riid: TGUID; var ppvHeap: Pointer): HRESULT; stdcall;
    SetStablePowerState: function(Self: Pointer; Enable: BOOL): HRESULT; stdcall;
    CreateCommandSignature: function(Self: Pointer; pDesc: Pointer; pRootSignature: Pointer; const riid: TGUID; var ppvCommandSignature: Pointer): HRESULT; stdcall;
    GetResourceTiling: procedure(Self: Pointer; pTiledResource: Pointer; pNumTilesForEntireResource: PUINT; pPackedMipDesc, pStandardTileShapeForNonPackedMips: Pointer; pNumSubresourceTilings: PUINT; FirstSubresourceTilingToGet: UINT; pSubresourceTilingsForNonPackedMips: Pointer); stdcall;
    GetAdapterLuid: pointer;
  end;
  PID3D12DeviceVtbl = ^ID3D12DeviceVtbl;
  ID3D12Device = record lpVtbl: PID3D12DeviceVtbl; end;
  PID3D12Device = ^ID3D12Device;

  // ID3D12CommandQueue
  ID3D12CommandQueueVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
    UpdateTileMappings: pointer;
    CopyTileMappings: pointer;
    ExecuteCommandLists: procedure(Self: Pointer; NumCommandLists: UINT; ppCommandLists: Pointer); stdcall;
    SetMarker: procedure(Self: Pointer; Metadata: UINT; pData: Pointer; Size: UINT); stdcall;
    BeginEvent: procedure(Self: Pointer; Metadata: UINT; pData: Pointer; Size: UINT); stdcall;
    EndEvent: procedure(Self: Pointer); stdcall;
    Signal: function(Self: Pointer; pFence: Pointer; Value: UINT64): HRESULT; stdcall;
    Wait: function(Self: Pointer; pFence: Pointer; Value: UINT64): HRESULT; stdcall;
    GetTimestampFrequency: function(Self: Pointer; out pFrequency: UINT64): HRESULT; stdcall;
    GetClockCalibration: function(Self: Pointer; out pGpuTimestamp, pCpuTimestamp: UINT64): HRESULT; stdcall;
    GetDesc: pointer;
  end;
  PID3D12CommandQueueVtbl = ^ID3D12CommandQueueVtbl;
  ID3D12CommandQueue = record lpVtbl: PID3D12CommandQueueVtbl; end;
  PID3D12CommandQueue = ^ID3D12CommandQueue;

  // ID3D12CommandAllocator
  ID3D12CommandAllocatorVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
    Reset: function(Self: Pointer): HRESULT; stdcall;
  end;
  PID3D12CommandAllocatorVtbl = ^ID3D12CommandAllocatorVtbl;
  ID3D12CommandAllocator = record lpVtbl: PID3D12CommandAllocatorVtbl; end;
  PID3D12CommandAllocator = ^ID3D12CommandAllocator;

  // ID3D12DescriptorHeap
  // Note: GetCPUDescriptorHandleForHeapStart uses hidden return parameter for struct in x86 MSVC ABI
  // The C code casts it as: void(__stdcall *)(ID3D12DescriptorHeap *, D3D12_CPU_DESCRIPTOR_HANDLE *)
  TGetCPUDescriptorHandleForHeapStartProc = procedure(Self: Pointer; pResult: PD3D12_CPU_DESCRIPTOR_HANDLE); stdcall;
  TGetGPUDescriptorHandleForHeapStartProc = procedure(Self: Pointer; pResult: Pointer); stdcall;
  
  ID3D12DescriptorHeapVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
    GetDesc: procedure(Self: Pointer; out pDesc: D3D12_DESCRIPTOR_HEAP_DESC); stdcall;
    GetCPUDescriptorHandleForHeapStart: Pointer;  // Use as procedure with out parameter
    GetGPUDescriptorHandleForHeapStart: Pointer;  // Use as procedure with out parameter
  end;
  PID3D12DescriptorHeapVtbl = ^ID3D12DescriptorHeapVtbl;
  ID3D12DescriptorHeap = record lpVtbl: PID3D12DescriptorHeapVtbl; end;
  PID3D12DescriptorHeap = ^ID3D12DescriptorHeap;

  // ID3D12Resource
  ID3D12ResourceVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
    Map: function(Self: Pointer; Subresource: UINT; pReadRange: Pointer; out ppData: Pointer): HRESULT; stdcall;
    Unmap: procedure(Self: Pointer; Subresource: UINT; pWrittenRange: Pointer); stdcall;
    GetDesc: pointer;
    GetGPUVirtualAddress: function(Self: Pointer): UINT64; stdcall;
    WriteToSubresource: function(Self: Pointer; DstSubresource: UINT; pDstBox: Pointer; pSrcData: Pointer; SrcRowPitch, SrcDepthPitch: UINT): HRESULT; stdcall;
    ReadFromSubresource: function(Self: Pointer; pDstData: Pointer; DstRowPitch, DstDepthPitch, SrcSubresource: UINT; pSrcBox: Pointer): HRESULT; stdcall;
    GetHeapProperties: function(Self: Pointer; pHeapProperties: Pointer; pHeapFlags: PUINT): HRESULT; stdcall;
  end;
  PID3D12ResourceVtbl = ^ID3D12ResourceVtbl;
  ID3D12Resource = record lpVtbl: PID3D12ResourceVtbl; end;
  PID3D12Resource = ^ID3D12Resource;

  // ID3D12Fence
  ID3D12FenceVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
    GetCompletedValue: function(Self: Pointer): UINT64; stdcall;
    SetEventOnCompletion: function(Self: Pointer; Value: UINT64; hEvent: THandle): HRESULT; stdcall;
    Signal: function(Self: Pointer; Value: UINT64): HRESULT; stdcall;
  end;
  PID3D12FenceVtbl = ^ID3D12FenceVtbl;
  ID3D12Fence = record lpVtbl: PID3D12FenceVtbl; end;
  PID3D12Fence = ^ID3D12Fence;

  // ID3D12PipelineState
  ID3D12PipelineStateVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
    GetCachedBlob: function(Self: Pointer; out ppBlob: Pointer): HRESULT; stdcall;
  end;
  PID3D12PipelineStateVtbl = ^ID3D12PipelineStateVtbl;
  ID3D12PipelineState = record lpVtbl: PID3D12PipelineStateVtbl; end;
  PID3D12PipelineState = ^ID3D12PipelineState;

  // ID3D12RootSignature
  ID3D12RootSignatureVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
  end;
  PID3D12RootSignatureVtbl = ^ID3D12RootSignatureVtbl;
  ID3D12RootSignature = record lpVtbl: PID3D12RootSignatureVtbl; end;
  PID3D12RootSignature = ^ID3D12RootSignature;

  // ID3D12GraphicsCommandList
  ID3D12GraphicsCommandListVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; out ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    GetPrivateData: function(Self: Pointer; const guid: TGUID; var pDataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateData: function(Self: Pointer; const guid: TGUID; DataSize: UINT; pData: Pointer): HRESULT; stdcall;
    SetPrivateDataInterface: function(Self: Pointer; const guid: TGUID; pData: Pointer): HRESULT; stdcall;
    SetName: function(Self: Pointer; Name: PWideChar): HRESULT; stdcall;
    GetDevice: function(Self: Pointer; const riid: TGUID; out ppvDevice): HRESULT; stdcall;
    _: function(Self: Pointer): UINT; stdcall;  // GetType
    Close: function(Self: Pointer): HRESULT; stdcall;
    Reset: function(Self: Pointer; pAllocator: Pointer; pInitialState: Pointer): HRESULT; stdcall;
    ClearState: procedure(Self: Pointer; pPipelineState: Pointer); stdcall;
    DrawInstanced: procedure(Self: Pointer; VertexCountPerInstance, InstanceCount, StartVertexLocation, StartInstanceLocation: UINT); stdcall;
    DrawIndexedInstanced: procedure(Self: Pointer; IndexCountPerInstance, InstanceCount, StartIndexLocation: UINT; BaseVertexLocation: Integer; StartInstanceLocation: UINT); stdcall;
    Dispatch: procedure(Self: Pointer; ThreadGroupCountX, ThreadGroupCountY, ThreadGroupCountZ: UINT); stdcall;
    CopyBufferRegion: procedure(Self: Pointer; pDstBuffer: Pointer; DstOffset: UINT64; pSrcBuffer: Pointer; SrcOffset, NumBytes: UINT64); stdcall;
    CopyTextureRegion: procedure(Self: Pointer; pDst: Pointer; DstX, DstY, DstZ: UINT; pSrc, pSrcBox: Pointer); stdcall;
    CopyResource: procedure(Self: Pointer; pDstResource, pSrcResource: Pointer); stdcall;
    CopyTiles: procedure(Self: Pointer; pTiledResource: Pointer; pTileRegionStartCoordinate, pTileRegionSize: Pointer; pBuffer: Pointer; BufferStartOffsetInBytes: UINT64; Flags: UINT); stdcall;
    ResolveSubresource: procedure(Self: Pointer; pDstResource: Pointer; DstSubresource: UINT; pSrcResource: Pointer; SrcSubresource, Format: UINT); stdcall;
    IASetPrimitiveTopology: procedure(Self: Pointer; PrimitiveTopology: UINT); stdcall;
    RSSetViewports: procedure(Self: Pointer; NumViewports: UINT; pViewports: Pointer); stdcall;
    RSSetScissorRects: procedure(Self: Pointer; NumRects: UINT; pRects: Pointer); stdcall;
    OMSetBlendFactor: procedure(Self: Pointer; BlendFactor: PSingle); stdcall;
    OMSetStencilRef: procedure(Self: Pointer; StencilRef: UINT); stdcall;
    SetPipelineState: procedure(Self: Pointer; pPipelineState: Pointer); stdcall;
    ResourceBarrier: procedure(Self: Pointer; NumBarriers: UINT; pBarriers: Pointer); stdcall;
    ExecuteBundle: procedure(Self: Pointer; pCommandList: Pointer); stdcall;
    SetDescriptorHeaps: procedure(Self: Pointer; NumDescriptorHeaps: UINT; ppDescriptorHeaps: Pointer); stdcall;
    SetComputeRootSignature: procedure(Self: Pointer; pRootSignature: Pointer); stdcall;
    SetGraphicsRootSignature: procedure(Self: Pointer; pRootSignature: Pointer); stdcall;
    SetComputeRootDescriptorTable: procedure(Self: Pointer; RootParameterIndex: UINT; BaseDescriptor: UINT64); stdcall;
    SetGraphicsRootDescriptorTable: procedure(Self: Pointer; RootParameterIndex: UINT; BaseDescriptor: UINT64); stdcall;
    SetComputeRoot32BitConstant: procedure(Self: Pointer; RootParameterIndex, SrcData, DestOffsetIn32BitValues: UINT); stdcall;
    SetGraphicsRoot32BitConstant: procedure(Self: Pointer; RootParameterIndex, SrcData, DestOffsetIn32BitValues: UINT); stdcall;
    SetComputeRoot32BitConstants: procedure(Self: Pointer; RootParameterIndex, Num32BitValuesToSet: UINT; pSrcData: Pointer; DestOffsetIn32BitValues: UINT); stdcall;
    SetGraphicsRoot32BitConstants: procedure(Self: Pointer; RootParameterIndex, Num32BitValuesToSet: UINT; pSrcData: Pointer; DestOffsetIn32BitValues: UINT); stdcall;
    SetComputeRootConstantBufferView: procedure(Self: Pointer; RootParameterIndex: UINT; BufferLocation: UINT64); stdcall;
    SetGraphicsRootConstantBufferView: procedure(Self: Pointer; RootParameterIndex: UINT; BufferLocation: UINT64); stdcall;
    SetComputeRootShaderResourceView: procedure(Self: Pointer; RootParameterIndex: UINT; BufferLocation: UINT64); stdcall;
    SetGraphicsRootShaderResourceView: procedure(Self: Pointer; RootParameterIndex: UINT; BufferLocation: UINT64); stdcall;
    SetComputeRootUnorderedAccessView: procedure(Self: Pointer; RootParameterIndex: UINT; BufferLocation: UINT64); stdcall;
    SetGraphicsRootUnorderedAccessView: procedure(Self: Pointer; RootParameterIndex: UINT; BufferLocation: UINT64); stdcall;
    IASetIndexBuffer: procedure(Self: Pointer; pView: Pointer); stdcall;
    IASetVertexBuffers: procedure(Self: Pointer; StartSlot, NumViews: UINT; pViews: Pointer); stdcall;
    SOSetTargets: procedure(Self: Pointer; StartSlot, NumViews: UINT; pViews: Pointer); stdcall;
    OMSetRenderTargets: procedure(Self: Pointer; NumRenderTargetDescriptors: UINT; pRenderTargetDescriptors: Pointer; RTsSingleHandleToDescriptorRange: BOOL; pDepthStencilDescriptor: Pointer); stdcall;
    ClearDepthStencilView: procedure(Self: Pointer; DepthStencilView: SIZE_T; ClearFlags: UINT; Depth: Single; Stencil: BYTE; NumRects: UINT; pRects: Pointer); stdcall;
    ClearRenderTargetView: procedure(Self: Pointer; RenderTargetView: SIZE_T; ColorRGBA: PSingle; NumRects: UINT; pRects: Pointer); stdcall;
    ClearUnorderedAccessViewUint: procedure(Self: Pointer; ViewGPUHandleInCurrentHeap: UINT64; ViewCPUHandle: SIZE_T; pResource: Pointer; Values: PUINT; NumRects: UINT; pRects: Pointer); stdcall;
    ClearUnorderedAccessViewFloat: procedure(Self: Pointer; ViewGPUHandleInCurrentHeap: UINT64; ViewCPUHandle: SIZE_T; pResource: Pointer; Values: PSingle; NumRects: UINT; pRects: Pointer); stdcall;
    DiscardResource: procedure(Self: Pointer; pResource, pRegion: Pointer); stdcall;
    BeginQuery: procedure(Self: Pointer; pQueryHeap: Pointer; Type_, Index: UINT); stdcall;
    EndQuery: procedure(Self: Pointer; pQueryHeap: Pointer; Type_, Index: UINT); stdcall;
    ResolveQueryData: procedure(Self: Pointer; pQueryHeap: Pointer; Type_, StartIndex, NumQueries: UINT; pDestinationBuffer: Pointer; AlignedDestinationBufferOffset: UINT64); stdcall;
    SetPredication: procedure(Self: Pointer; pBuffer: Pointer; AlignedBufferOffset: UINT64; Operation: UINT); stdcall;
    SetMarker: procedure(Self: Pointer; Metadata: UINT; pData: Pointer; Size: UINT); stdcall;
    BeginEvent: procedure(Self: Pointer; Metadata: UINT; pData: Pointer; Size: UINT); stdcall;
    EndEvent: procedure(Self: Pointer); stdcall;
    ExecuteIndirect: procedure(Self: Pointer; pCommandSignature: Pointer; MaxCommandCount: UINT; pArgumentBuffer: Pointer; ArgumentBufferOffset: UINT64; pCountBuffer: Pointer; CountBufferOffset: UINT64); stdcall;
  end;
  PID3D12GraphicsCommandListVtbl = ^ID3D12GraphicsCommandListVtbl;
  ID3D12GraphicsCommandList = record lpVtbl: PID3D12GraphicsCommandListVtbl; end;
  PID3D12GraphicsCommandList = ^ID3D12GraphicsCommandList;

// ===========================================
// External Functions
// ===========================================
function CreateDXGIFactory1(const riid: TGUID; out ppFactory): HRESULT; stdcall; external 'dxgi.dll';
// D3D12 Debug interface
const
  IID_ID3D12Debug: TGUID = '{344488b7-6846-474b-b989-f027448245e0}';

type
  ID3D12DebugVtbl = record
    QueryInterface: function(Self: Pointer; const riid: TGUID; var ppvObject): HRESULT; stdcall;
    AddRef: function(Self: Pointer): ULONG; stdcall;
    Release: function(Self: Pointer): ULONG; stdcall;
    EnableDebugLayer: procedure(Self: Pointer); stdcall;
  end;
  PID3D12DebugVtbl = ^ID3D12DebugVtbl;
  ID3D12Debug = record lpVtbl: PID3D12DebugVtbl; end;
  PID3D12Debug = ^ID3D12Debug;

function D3D12GetDebugInterface(const riid: TGUID; out ppvDebug): HRESULT; stdcall; external 'd3d12.dll';

function D3D12CreateDevice(pAdapter: Pointer; MinimumFeatureLevel: UINT; const riid: TGUID; out ppDevice): HRESULT; stdcall; external 'd3d12.dll';
function D3D12SerializeRootSignature(const pRootSignature: D3D12_ROOT_SIGNATURE_DESC; Version: UINT; out ppBlob: PID3DBlob; ppErrorBlob: Pointer): HRESULT; stdcall; external 'd3d12.dll';
function D3DCompileFromFile(pFileName: PWideChar; pDefines, pInclude: Pointer; pEntrypoint, pTarget: PAnsiChar; Flags1, Flags2: UINT; out ppCode: PID3DBlob; ppErrorMsgs: Pointer): HRESULT; stdcall; external 'd3dcompiler_47.dll';

// ===========================================
// Global Variables
// ===========================================
var
  g_hWnd: HWND;
  g_swapChain: PIDXGISwapChain3;
  g_device: PID3D12Device;
  g_renderTarget: array[0..FRAMES-1] of PID3D12Resource;
  g_commandAllocator: PID3D12CommandAllocator;
  g_commandQueue: PID3D12CommandQueue;
  g_descriptorHeap: PID3D12DescriptorHeap;
  g_pso: PID3D12PipelineState;
  g_commandList: PID3D12GraphicsCommandList;
  g_rootSignature: PID3D12RootSignature;
  g_fenceEvent: THandle;
  g_fence: PID3D12Fence;
  g_fenceValue: UINT64;
  g_frameIndex: UINT;
  g_buffer: PID3D12Resource;
  g_rtvDescriptorSize: UINT;

// ===========================================
// Helper Functions
// ===========================================
var
  logFile: TextFile;

procedure InitLog;
begin
  AssignFile(logFile, 'debug.log');
  Rewrite(logFile);
end;

procedure CloseLog;
begin
  CloseFile(logFile);
end;

procedure DebugLog(const Msg: string);
begin
  WriteLn(logFile, Msg);
  Flush(logFile);
end;

// Helper functions to call GetCPUDescriptorHandleForHeapStart
// C code shows: ((void(__stdcall *)(ID3D12DescriptorHeap *, D3D12_CPU_DESCRIPTOR_HANDLE *))
//                 g_descriptorHeap->lpVtbl->GetCPUDescriptorHandleForHeapStart)(g_descriptorHeap, &rtvHandle);

type
  TGetCPUHandleProc = procedure(Self: Pointer; pResult: PD3D12_CPU_DESCRIPTOR_HANDLE); stdcall;

procedure GetCPUDescriptorHandleForHeapStart(heap: PID3D12DescriptorHeap; pHandle: PD3D12_CPU_DESCRIPTOR_HANDLE);
var
  proc: TGetCPUHandleProc;
begin
  DebugLog('  [Helper] Entered function');
  {$IFDEF CPU64}
  DebugLog('  [Helper] heap=' + IntToHex(NativeUInt(heap), 16) + ' pHandle=' + IntToHex(NativeUInt(pHandle), 16));
  {$ELSE}
  DebugLog('  [Helper] heap=' + IntToHex(NativeUInt(heap), 8) + ' pHandle=' + IntToHex(NativeUInt(pHandle), 8));
  {$ENDIF}
  // Get the function pointer from vtable slot 9
  proc := TGetCPUHandleProc(heap^.lpVtbl^.GetCPUDescriptorHandleForHeapStart);
  {$IFDEF CPU64}
  DebugLog('  [Helper] Got proc at ' + IntToHex(NativeUInt(heap^.lpVtbl^.GetCPUDescriptorHandleForHeapStart), 16));
  {$ELSE}
  DebugLog('  [Helper] Got proc at ' + IntToHex(NativeUInt(heap^.lpVtbl^.GetCPUDescriptorHandleForHeapStart), 8));
  {$ENDIF}
  DebugLog('  [Helper] Calling proc...');
  // Call with (Self, pResult) order as per C code
  proc(heap, pHandle);
  DebugLog('  [Helper] Returned from proc');
end;

// Helper for CreateRenderTargetView - vtable index #20
// void CreateRenderTargetView(ID3D12Device*, ID3D12Resource*, const D3D12_RENDER_TARGET_VIEW_DESC*, D3D12_CPU_DESCRIPTOR_HANDLE)

{$IFDEF CPU64}
// 64-bit: Use direct vtable call
procedure CreateRenderTargetViewHelper(device: PID3D12Device; resource: PID3D12Resource; pDesc: Pointer; handle: SIZE_T);
begin
  DebugLog('  [CreateRTV] device=' + IntToHex(NativeUInt(device), 16) + 
           ' resource=' + IntToHex(NativeUInt(resource), 16) +
           ' handle=' + IntToHex(handle, 16));
  DebugLog('  [CreateRTV] funcPtr=' + IntToHex(NativeUInt(@device^.lpVtbl^.CreateRenderTargetView), 16));
  
  // Use direct vtable call
  device^.lpVtbl^.CreateRenderTargetView(device, resource, pDesc, handle);
  
  DebugLog('  [CreateRTV] Returned OK');
end;
{$ELSE}
// 32-bit: Use assembly for precise control over calling convention
var
  g_RTV_Device: Pointer;
  g_RTV_Resource: Pointer;
  g_RTV_Desc: Pointer;
  g_RTV_Handle: DWORD;
  g_RTV_FuncPtr: Pointer;

procedure CreateRenderTargetViewAsm; assembler;
// All parameters are in global variables
// stdcall: args pushed right-to-left, callee cleans stack (16 bytes for 4 DWORDs)
asm
  // Load values into registers first
  mov eax, g_RTV_Handle
  push eax                      // arg4: DestDescriptor (4 bytes value)
  mov eax, g_RTV_Desc
  push eax                      // arg3: pDesc (nil)
  mov eax, g_RTV_Resource
  push eax                      // arg2: pResource
  mov eax, g_RTV_Device
  push eax                      // arg1: this pointer
  mov eax, g_RTV_FuncPtr
  call eax                      // call - stdcall cleans 16 bytes
end;

procedure CreateRenderTargetViewHelper(device: PID3D12Device; resource: PID3D12Resource; pDesc: Pointer; handle: SIZE_T);
begin
  // Store in globals for asm access FIRST, before any other operations
  g_RTV_Device := device;
  g_RTV_Resource := resource;
  g_RTV_Desc := pDesc;
  g_RTV_Handle := DWORD(handle);
  
  // Get vtable and function pointer (index 20)
  g_RTV_FuncPtr := PPointer(PByte(PPointer(device)^) + 20 * 4)^;
  
  DebugLog('  [CreateRTV] Globals set:');
  DebugLog('    device=' + IntToHex(DWORD(g_RTV_Device), 8));
  DebugLog('    resource=' + IntToHex(DWORD(g_RTV_Resource), 8));
  DebugLog('    desc=' + IntToHex(DWORD(g_RTV_Desc), 8));
  DebugLog('    handle=' + IntToHex(g_RTV_Handle, 8));
  DebugLog('    funcPtr=' + IntToHex(DWORD(g_RTV_FuncPtr), 8));
  DebugLog('  [CreateRTV] Calling asm...');
  
  CreateRenderTargetViewAsm;
  
  DebugLog('  [CreateRTV] Returned OK');
end;
{$ENDIF}

procedure WaitForPreviousFrame;
var
  fence: UINT64;
begin
  fence := g_fenceValue;
  g_commandQueue^.lpVtbl^.Signal(g_commandQueue, g_fence, fence);
  Inc(g_fenceValue);

  if g_fence^.lpVtbl^.GetCompletedValue(g_fence) < fence then
  begin
    g_fence^.lpVtbl^.SetEventOnCompletion(g_fence, fence, g_fenceEvent);
    WaitForSingleObject(g_fenceEvent, INFINITE);
  end;

  g_frameIndex := g_swapChain^.lpVtbl^.GetCurrentBackBufferIndex(g_swapChain);
end;

// ===========================================
// Window Procedure
// ===========================================
function WindowProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  if ((uMsg = WM_KEYUP) and (wParam = VK_ESCAPE)) or (uMsg = WM_CLOSE) or (uMsg = WM_DESTROY) then
  begin
    PostQuitMessage(0);
    Result := 0;
  end
  else
    Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
end;

// ===========================================
// Main Program
// ===========================================
var
  msg: TMsg;
  wc: WNDCLASS;
  pFactory: PIDXGIFactory4;
  queueDesc: D3D12_COMMAND_QUEUE_DESC;
  descSwapChain: DXGI_SWAP_CHAIN_DESC;
  SwapChain: PIDXGISwapChain;
  layout: array[0..1] of D3D12_INPUT_ELEMENT_DESC;
  signature, error: PID3DBlob;
  descRootSignature: D3D12_ROOT_SIGNATURE_DESC;
  rasterizer: D3D12_RASTERIZER_DESC;
  blendstate: D3D12_BLEND_DESC;
  pDesc: D3D12_GRAPHICS_PIPELINE_STATE_DESC;
  vertexShader, pixelShader: PID3DBlob;
  descHeap: D3D12_DESCRIPTOR_HEAP_DESC;
  rtvHandle: D3D12_CPU_DESCRIPTOR_HANDLE;
  i: UINT;
  mViewport: D3D12_VIEWPORT;
  mRectScissor: D3D12_RECT;
  vertices: array[0..2] of VERTEX;
  heapProperties: D3D12_HEAP_PROPERTIES;
  vertexBufferDesc: D3D12_RESOURCE_DESC;
  data: Pointer;
  mDescViewBufVert: D3D12_VERTEX_BUFFER_VIEW;
  barrierRTAsTexture, barrierRTForPresent: D3D12_RESOURCE_BARRIER;
  clearColor: array[0..3] of Single;
  ppCommandLists: array[0..0] of Pointer;
  exitLoop: Boolean;
  hr: HRESULT;
  refCount: ULONG;
  debugController: PID3D12Debug;
  pAllocator: Pointer;
  pDevice: Pointer;
  pCommandQueue: Pointer;
  pRootSignature: Pointer;
  pPSO: Pointer;
  pDescriptorHeap: Pointer;
  pCommandList: Pointer;
  pBuffer: Pointer;
  pFence: Pointer;

begin
  InitLog;
  DebugLog('Starting...');

  // Register window class
  ZeroMemory(@wc, SizeOf(WNDCLASS));
  wc.style := CS_OWNDC or CS_HREDRAW or CS_VREDRAW;
  wc.lpfnWndProc := @WindowProc;
  wc.hInstance := 0;
  wc.lpszClassName := 'helloWorld';
  wc.hbrBackground := COLOR_WINDOW + 1;
  RegisterClass(wc);

  // Create window
  g_hWnd := CreateWindowEx(0, wc.lpszClassName, 'Hello, World!',
    WS_VISIBLE or WS_OVERLAPPEDWINDOW,
    0, 0, WIDTH, HEIGHT, 0, 0, 0, nil);

  DebugLog('Window created');

  // Enable D3D12 Debug Layer
  debugController := nil;
  hr := D3D12GetDebugInterface(IID_ID3D12Debug, debugController);
  if Succeeded(hr) then begin
    debugController^.lpVtbl^.EnableDebugLayer(debugController);
    debugController^.lpVtbl^.Release(debugController);
    DebugLog('D3D12 Debug layer enabled');
  end else begin
    DebugLog('D3D12 Debug layer not available: ' + IntToHex(hr, 8));
  end;

  // Create DXGI Factory
  hr := CreateDXGIFactory1(IID_IDXGIFactory4, pFactory);
  if Failed(hr) then begin DebugLog('CreateDXGIFactory1 failed: ' + IntToHex(hr, 8)); Halt(1); end;
  DebugLog('Factory created');

  // Create D3D12 Device
  hr := D3D12CreateDevice(nil, D3D_FEATURE_LEVEL_12_0, IID_ID3D12Device, g_device);
  if Failed(hr) then begin DebugLog('D3D12CreateDevice failed: ' + IntToHex(hr, 8)); Halt(1); end;
  DebugLog('Device created');

  // Create Command Queue
  ZeroMemory(@queueDesc, SizeOf(queueDesc));
  queueDesc.Type_ := D3D12_COMMAND_LIST_TYPE_DIRECT;
  queueDesc.Flags := D3D12_COMMAND_QUEUE_FLAG_NONE;
  pCommandQueue := nil;
  hr := g_device^.lpVtbl^.CreateCommandQueue(g_device, queueDesc, IID_ID3D12CommandQueue, pCommandQueue);
  if Failed(hr) or (pCommandQueue = nil) then begin DebugLog('CreateCommandQueue failed: ' + IntToHex(hr, 8)); Halt(1); end;
  g_commandQueue := PID3D12CommandQueue(pCommandQueue);
  DebugLog('CommandQueue created');

  // Create Swap Chain
  ZeroMemory(@descSwapChain, SizeOf(descSwapChain));
  descSwapChain.BufferDesc.Width := WIDTH;
  descSwapChain.BufferDesc.Height := HEIGHT;
  descSwapChain.BufferDesc.Format := DXGI_FORMAT_R8G8B8A8_UNORM;
  descSwapChain.SampleDesc.Count := 1;
  descSwapChain.BufferUsage := DXGI_USAGE_RENDER_TARGET_OUTPUT;
  descSwapChain.BufferCount := FRAMES;
  descSwapChain.OutputWindow := g_hWnd;
  descSwapChain.Windowed := True;
  descSwapChain.SwapEffect := DXGI_SWAP_EFFECT_FLIP_DISCARD;

  hr := pFactory^.lpVtbl^.CreateSwapChain(pFactory, g_commandQueue, @descSwapChain, SwapChain);
  if Failed(hr) then begin DebugLog('CreateSwapChain failed: ' + IntToHex(hr, 8)); Halt(1); end;

  hr := SwapChain^.lpVtbl^.QueryInterface(SwapChain, IID_IDXGISwapChain3, g_swapChain);
  SwapChain^.lpVtbl^.Release(SwapChain);
  if Failed(hr) then begin DebugLog('QueryInterface SwapChain3 failed: ' + IntToHex(hr, 8)); Halt(1); end;
  DebugLog('SwapChain created');

  // Initialize current back buffer index
  g_frameIndex := g_swapChain^.lpVtbl^.GetCurrentBackBufferIndex(g_swapChain);

  // Setup Input Layout
  layout[0].SemanticName := 'POSITION';
  layout[0].SemanticIndex := 0;
  layout[0].Format := DXGI_FORMAT_R32G32B32_FLOAT;
  layout[0].InputSlot := 0;
  layout[0].AlignedByteOffset := 0;
  layout[0].InputSlotClass := D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA;
  layout[0].InstanceDataStepRate := 0;

  layout[1].SemanticName := 'COLOR';
  layout[1].SemanticIndex := 0;
  layout[1].Format := DXGI_FORMAT_R32G32B32A32_FLOAT;
  layout[1].InputSlot := 0;
  layout[1].AlignedByteOffset := 12;
  layout[1].InputSlotClass := D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA;
  layout[1].InstanceDataStepRate := 0;

  // Create Root Signature
  ZeroMemory(@descRootSignature, SizeOf(descRootSignature));
  descRootSignature.Flags := D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

  hr := D3D12SerializeRootSignature(descRootSignature, D3D_ROOT_SIGNATURE_VERSION_1, signature, @error);
  if Failed(hr) then begin DebugLog('D3D12SerializeRootSignature failed: ' + IntToHex(hr, 8)); Halt(1); end;

  pRootSignature := nil;
  hr := g_device^.lpVtbl^.CreateRootSignature(g_device, 0,
    signature^.lpVtbl^.GetBufferPointer(signature),
    signature^.lpVtbl^.GetBufferSize(signature),
    IID_ID3D12RootSignature, pRootSignature);
  if Failed(hr) or (pRootSignature = nil) then begin DebugLog('CreateRootSignature failed: ' + IntToHex(hr, 8)); Halt(1); end;
  g_rootSignature := PID3D12RootSignature(pRootSignature);
  DebugLog('RootSignature created');

  // Setup Rasterizer State - DISABLED CULLING to ensure triangle is visible
  ZeroMemory(@rasterizer, SizeOf(rasterizer));
  rasterizer.FillMode := D3D12_FILL_MODE_SOLID;
  rasterizer.CullMode := D3D12_CULL_MODE_NONE;  // Changed from BACK to NONE
  rasterizer.FrontCounterClockwise := False;
  rasterizer.DepthClipEnable := True;

  // Setup Blend State
  ZeroMemory(@blendstate, SizeOf(blendstate));
  blendstate.RenderTarget[0].BlendEnable := False;
  blendstate.RenderTarget[0].SrcBlend := 1;
  blendstate.RenderTarget[0].DestBlend := 0;
  blendstate.RenderTarget[0].BlendOp := D3D12_BLEND_OP_ADD;
  blendstate.RenderTarget[0].SrcBlendAlpha := 1;
  blendstate.RenderTarget[0].DestBlendAlpha := 0;
  blendstate.RenderTarget[0].BlendOpAlpha := D3D12_BLEND_OP_ADD;
  blendstate.RenderTarget[0].LogicOp := D3D12_LOGIC_OP_NOOP;
  blendstate.RenderTarget[0].RenderTargetWriteMask := D3D12_COLOR_WRITE_ENABLE_ALL;

  // Compile Shaders
  hr := D3DCompileFromFile('hello.hlsl', nil, nil, 'VSMain', 'vs_5_0', 0, 0, vertexShader, nil);
  if Failed(hr) then begin DebugLog('Compile VS failed: ' + IntToHex(hr, 8)); Halt(1); end;

  hr := D3DCompileFromFile('hello.hlsl', nil, nil, 'PSMain', 'ps_5_0', 0, 0, pixelShader, nil);
  if Failed(hr) then begin DebugLog('Compile PS failed: ' + IntToHex(hr, 8)); Halt(1); end;
  DebugLog('Shaders compiled');

  // Create Pipeline State Object
  ZeroMemory(@pDesc, SizeOf(pDesc));
  pDesc.pRootSignature := g_rootSignature;
  pDesc.VS.pShaderBytecode := vertexShader^.lpVtbl^.GetBufferPointer(vertexShader);
  pDesc.VS.BytecodeLength := vertexShader^.lpVtbl^.GetBufferSize(vertexShader);
  pDesc.PS.pShaderBytecode := pixelShader^.lpVtbl^.GetBufferPointer(pixelShader);
  pDesc.PS.BytecodeLength := pixelShader^.lpVtbl^.GetBufferSize(pixelShader);
  pDesc.InputLayout.pInputElementDescs := @layout[0];
  pDesc.InputLayout.NumElements := 2;
  pDesc.RasterizerState := rasterizer;
  pDesc.BlendState := blendstate;
  pDesc.SampleMask := $FFFFFFFF;
  pDesc.PrimitiveTopologyType := D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
  pDesc.NumRenderTargets := 1;
  pDesc.RTVFormats[0] := DXGI_FORMAT_R8G8B8A8_UNORM;
  pDesc.SampleDesc.Count := 1;

  pPSO := nil;
  hr := g_device^.lpVtbl^.CreateGraphicsPipelineState(g_device, pDesc, IID_ID3D12PipelineState, pPSO);
  if Failed(hr) or (pPSO = nil) then begin DebugLog('CreateGraphicsPipelineState failed: ' + IntToHex(hr, 8)); Halt(1); end;
  g_pso := PID3D12PipelineState(pPSO);
  DebugLog('PSO created');

  // Create Descriptor Heap
  ZeroMemory(@descHeap, SizeOf(descHeap));
  descHeap.Type_ := D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
  descHeap.NumDescriptors := FRAMES;
  descHeap.Flags := D3D12_DESCRIPTOR_HEAP_FLAG_NONE;

  pDescriptorHeap := nil;
  hr := g_device^.lpVtbl^.CreateDescriptorHeap(g_device, descHeap, IID_ID3D12DescriptorHeap, pDescriptorHeap);
  if Failed(hr) or (pDescriptorHeap = nil) then begin DebugLog('CreateDescriptorHeap failed: ' + IntToHex(hr, 8)); Halt(1); end;
  g_descriptorHeap := PID3D12DescriptorHeap(pDescriptorHeap);
  DebugLog('DescriptorHeap created');

  g_rtvDescriptorSize := g_device^.lpVtbl^.GetDescriptorHandleIncrementSize(g_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
  DebugLog('RTV size: ' + IntToStr(g_rtvDescriptorSize));

  // Debug: Check descriptor heap and vtable
  DebugLog('g_descriptorHeap ptr: ' + IntToHex(NativeUInt(g_descriptorHeap), 8));
  DebugLog('g_descriptorHeap^.lpVtbl ptr: ' + IntToHex(NativeUInt(g_descriptorHeap^.lpVtbl), 8));
  DebugLog('GetCPUDescriptorHandleForHeapStart func ptr: ' + IntToHex(NativeUInt(g_descriptorHeap^.lpVtbl^.GetCPUDescriptorHandleForHeapStart), 8));
  DebugLog('About to call GetCPUDescriptorHandleForHeapStart...');
  
  // Create Render Target Views - using helper procedure for correct calling convention
  GetCPUDescriptorHandleForHeapStart(g_descriptorHeap, @rtvHandle);
  DebugLog('Got heap start: ' + IntToHex(rtvHandle.ptr, 8));
  
  for i := 0 to FRAMES - 1 do
  begin
    DebugLog('Getting buffer ' + IntToStr(i));
    hr := g_swapChain^.lpVtbl^.GetBuffer(g_swapChain, i, IID_ID3D12Resource, g_renderTarget[i]);
    if Failed(hr) then begin DebugLog('GetBuffer failed: ' + IntToHex(hr, 8)); Halt(1); end;
    DebugLog('Got buffer ' + IntToStr(i) + ' ptr=' + IntToHex(NativeUInt(g_renderTarget[i]), 8));
    
    DebugLog('Creating RTV ' + IntToStr(i) + ' at handle ' + IntToHex(rtvHandle.ptr, 8));
    // Use assembly helper for precise calling convention control
    CreateRenderTargetViewHelper(g_device, g_renderTarget[i], nil, rtvHandle.ptr);
    DebugLog('RTV ' + IntToStr(i) + ' created');
    rtvHandle.ptr := rtvHandle.ptr + g_rtvDescriptorSize;
  end;
  DebugLog('RTVs created');

  // Create Command Allocator
  DebugLog('Before CreateCommandAllocator');
  hr := g_device^.lpVtbl^.CreateCommandAllocator(g_device, D3D12_COMMAND_LIST_TYPE_DIRECT,
    IID_ID3D12CommandAllocator, Pointer(g_commandAllocator));
  DebugLog('After CreateCommandAllocator hr=' + IntToHex(hr, 8));
  if Failed(hr) or (g_commandAllocator = nil) then begin DebugLog('CreateCommandAllocator failed: ' + IntToHex(hr, 8)); Halt(1); end;
  DebugLog('CommandAllocator created');

  // Create Command List
  DebugLog('Before CreateCommandList');
  pCommandList := nil;
  hr := g_device^.lpVtbl^.CreateCommandList(g_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT,
    g_commandAllocator, g_pso, IID_ID3D12GraphicsCommandList, pCommandList);
  DebugLog('After CreateCommandList hr=' + IntToHex(hr, 8));
  if Failed(hr) or (pCommandList = nil) then begin DebugLog('CreateCommandList failed: ' + IntToHex(hr, 8)); Halt(1); end;
  g_commandList := PID3D12GraphicsCommandList(pCommandList);
  DebugLog('CommandList created');

  // Setup Viewport and Scissor Rect
  mViewport.TopLeftX := 0;
  mViewport.TopLeftY := 0;
  mViewport.Width := WIDTH;
  mViewport.Height := HEIGHT;
  mViewport.MinDepth := 0.0;
  mViewport.MaxDepth := 1.0;

  mRectScissor.left := 0;
  mRectScissor.top := 0;
  mRectScissor.right := WIDTH;
  mRectScissor.bottom := HEIGHT;

  // Create Vertex Buffer - vertices in clockwise order for front face
  vertices[0].position[0] :=  0.0; vertices[0].position[1] :=  0.5; vertices[0].position[2] := 0.0;
  vertices[0].color[0] := 1.0; vertices[0].color[1] := 0.0; vertices[0].color[2] := 0.0; vertices[0].color[3] := 1.0;

  vertices[1].position[0] :=  0.5; vertices[1].position[1] := -0.5; vertices[1].position[2] := 0.0;
  vertices[1].color[0] := 0.0; vertices[1].color[1] := 1.0; vertices[1].color[2] := 0.0; vertices[1].color[3] := 1.0;

  vertices[2].position[0] := -0.5; vertices[2].position[1] := -0.5; vertices[2].position[2] := 0.0;
  vertices[2].color[0] := 0.0; vertices[2].color[1] := 0.0; vertices[2].color[2] := 1.0; vertices[2].color[3] := 1.0;

  ZeroMemory(@heapProperties, SizeOf(heapProperties));
  heapProperties.Type_ := D3D12_HEAP_TYPE_UPLOAD;
  heapProperties.CPUPageProperty := D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
  heapProperties.MemoryPoolPreference := D3D12_MEMORY_POOL_UNKNOWN;
  heapProperties.CreationNodeMask := 1;
  heapProperties.VisibleNodeMask := 1;

  ZeroMemory(@vertexBufferDesc, SizeOf(vertexBufferDesc));
  vertexBufferDesc.Dimension := D3D12_RESOURCE_DIMENSION_BUFFER;
  vertexBufferDesc.Width := SizeOf(vertices);
  vertexBufferDesc.Height := 1;
  vertexBufferDesc.DepthOrArraySize := 1;
  vertexBufferDesc.MipLevels := 1;
  vertexBufferDesc.Format := DXGI_FORMAT_UNKNOWN;
  vertexBufferDesc.SampleDesc.Count := 1;
  vertexBufferDesc.Layout := 1;
  vertexBufferDesc.Flags := 0;

  DebugLog('Before CreateCommittedResource (vertex buffer)');
  pBuffer := nil;
  hr := g_device^.lpVtbl^.CreateCommittedResource(g_device, heapProperties, 0,
    vertexBufferDesc, D3D12_RESOURCE_STATE_GENERIC_READ, nil, IID_ID3D12Resource, pBuffer);
  DebugLog('After CreateCommittedResource hr=' + IntToHex(hr, 8));
  if Failed(hr) or (pBuffer = nil) then begin DebugLog('CreateCommittedResource failed: ' + IntToHex(hr, 8)); Halt(1); end;
  g_buffer := PID3D12Resource(pBuffer);
  DebugLog('VertexBuffer created');

  // Map and copy vertex data
  DebugLog('Before Map vertex buffer');
  hr := g_buffer^.lpVtbl^.Map(g_buffer, 0, nil, data);
  DebugLog('After Map hr=' + IntToHex(hr, 8));
  if Failed(hr) then begin DebugLog('Map failed: ' + IntToHex(hr, 8)); Halt(1); end;
  Move(vertices, data^, SizeOf(vertices));
  g_buffer^.lpVtbl^.Unmap(g_buffer, 0, nil);
  DebugLog('Vertex data copied');

  // Setup Vertex Buffer View
  mDescViewBufVert.BufferLocation := g_buffer^.lpVtbl^.GetGPUVirtualAddress(g_buffer);
  mDescViewBufVert.SizeInBytes := SizeOf(vertices);
  mDescViewBufVert.StrideInBytes := SizeOf(VERTEX);
  DebugLog('VBV GPU addr: ' + IntToHex(mDescViewBufVert.BufferLocation, 16));

  // Close initial command list
  DebugLog('Before initial CommandList Close');
  hr := g_commandList^.lpVtbl^.Close(g_commandList);
  DebugLog('After initial CommandList Close hr=' + IntToHex(hr, 8));
  if Failed(hr) then begin DebugLog('Close failed: ' + IntToHex(hr, 8)); Halt(1); end;
  DebugLog('CommandList closed');

  // Create Fence
  DebugLog('Before CreateFence');
  pFence := nil;
  hr := g_device^.lpVtbl^.CreateFence(g_device, 0, D3D12_FENCE_FLAG_NONE, IID_ID3D12Fence, pFence);
  DebugLog('After CreateFence hr=' + IntToHex(hr, 8));
  if Failed(hr) or (pFence = nil) then begin DebugLog('CreateFence failed: ' + IntToHex(hr, 8)); Halt(1); end;
  g_fence := PID3D12Fence(pFence);

  g_fenceValue := 1;
  g_fenceEvent := CreateEvent(nil, False, False, nil);
  DebugLog('Fence created, entering main loop');

  // Main Loop
  exitLoop := False;
  while not exitLoop do
  begin
    // Process all pending messages first
    while PeekMessage(msg, 0, 0, 0, PM_REMOVE) do
    begin
      if msg.message = WM_QUIT then
        exitLoop := True;
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;

    if not exitLoop then
    begin
      // Refresh current back buffer index
      g_frameIndex := g_swapChain^.lpVtbl^.GetCurrentBackBufferIndex(g_swapChain);

      // Reset
      hr := g_commandAllocator^.lpVtbl^.Reset(g_commandAllocator);
      if Failed(hr) then begin DebugLog('Allocator Reset failed: ' + IntToHex(hr, 8)); exitLoop := True; continue; end;
      hr := g_commandList^.lpVtbl^.Reset(g_commandList, g_commandAllocator, g_pso);
      if Failed(hr) then begin DebugLog('CommandList Reset failed: ' + IntToHex(hr, 8)); exitLoop := True; continue; end;

      // Set state
      g_commandList^.lpVtbl^.SetGraphicsRootSignature(g_commandList, g_rootSignature);
      g_commandList^.lpVtbl^.RSSetViewports(g_commandList, 1, @mViewport);
      g_commandList^.lpVtbl^.RSSetScissorRects(g_commandList, 1, @mRectScissor);

      // Transition to render target state
      ZeroMemory(@barrierRTAsTexture, SizeOf(barrierRTAsTexture));
      barrierRTAsTexture.Type_ := D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
      barrierRTAsTexture.Transition.pResource := g_renderTarget[g_frameIndex];
      barrierRTAsTexture.Transition.Subresource := D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
      barrierRTAsTexture.Transition.StateBefore := D3D12_RESOURCE_STATE_PRESENT;
      barrierRTAsTexture.Transition.StateAfter := D3D12_RESOURCE_STATE_RENDER_TARGET;
      g_commandList^.lpVtbl^.ResourceBarrier(g_commandList, 1, @barrierRTAsTexture);

      // Get RTV handle for current frame - using helper procedure
      GetCPUDescriptorHandleForHeapStart(g_descriptorHeap, @rtvHandle);
      rtvHandle.ptr := rtvHandle.ptr + (g_frameIndex * g_rtvDescriptorSize);

      // Clear render target with a visible color (dark blue)
      clearColor[0] := 0.0;
      clearColor[1] := 0.0;
      clearColor[2] := 0.3;
      clearColor[3] := 1.0;
      g_commandList^.lpVtbl^.ClearRenderTargetView(g_commandList, rtvHandle.ptr, @clearColor[0], 0, nil);
      
      // Set render target
      g_commandList^.lpVtbl^.OMSetRenderTargets(g_commandList, 1, @rtvHandle, False, nil);

      // Draw
      g_commandList^.lpVtbl^.IASetPrimitiveTopology(g_commandList, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
      g_commandList^.lpVtbl^.IASetVertexBuffers(g_commandList, 0, 1, @mDescViewBufVert);
      g_commandList^.lpVtbl^.DrawInstanced(g_commandList, 3, 1, 0, 0);

      // Transition to present state
      ZeroMemory(@barrierRTForPresent, SizeOf(barrierRTForPresent));
      barrierRTForPresent.Type_ := D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
      barrierRTForPresent.Transition.pResource := g_renderTarget[g_frameIndex];
      barrierRTForPresent.Transition.Subresource := D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
      barrierRTForPresent.Transition.StateBefore := D3D12_RESOURCE_STATE_RENDER_TARGET;
      barrierRTForPresent.Transition.StateAfter := D3D12_RESOURCE_STATE_PRESENT;
      g_commandList^.lpVtbl^.ResourceBarrier(g_commandList, 1, @barrierRTForPresent);

      // Execute
      hr := g_commandList^.lpVtbl^.Close(g_commandList);
      if Failed(hr) then begin DebugLog('Close failed: ' + IntToHex(hr, 8)); exitLoop := True; continue; end;
      ppCommandLists[0] := g_commandList;
      g_commandQueue^.lpVtbl^.ExecuteCommandLists(g_commandQueue, 1, @ppCommandLists[0]);

      // Present
      hr := g_swapChain^.lpVtbl^.Present(g_swapChain, 1, 0);
      if Failed(hr) then begin DebugLog('Present failed: ' + IntToHex(hr, 8)); exitLoop := True; continue; end;

      WaitForPreviousFrame;
    end;
  end;

  // Cleanup
  WaitForPreviousFrame;
  CloseHandle(g_fenceEvent);

  g_device^.lpVtbl^.Release(g_device);
  g_swapChain^.lpVtbl^.Release(g_swapChain);
  g_buffer^.lpVtbl^.Release(g_buffer);
  for i := 0 to FRAMES - 1 do
    g_renderTarget[i]^.lpVtbl^.Release(g_renderTarget[i]);
  g_commandAllocator^.lpVtbl^.Release(g_commandAllocator);
  g_commandQueue^.lpVtbl^.Release(g_commandQueue);
  g_descriptorHeap^.lpVtbl^.Release(g_descriptorHeap);
  g_commandList^.lpVtbl^.Release(g_commandList);
  g_pso^.lpVtbl^.Release(g_pso);
  g_fence^.lpVtbl^.Release(g_fence);
  g_rootSignature^.lpVtbl^.Release(g_rootSignature);
  
  CloseLog;
end.

