# hello.rb (Ruby 3.3 x64 / Fiddle only) - DirectX 12 Harmonograph via Compute Shader
require 'fiddle/import'
require 'fiddle/types'

# ============================================================
# Memory Helper (keep buffers alive)
# ============================================================
module Mem
  @keep = []
  def self.keep(p) = (@keep << p; p)

  def self.to_ptr(data)
    return 0 if data.nil?
    data = data.b
    p = Fiddle::Pointer.malloc(data.bytesize)
    p[0, data.bytesize] = data
    keep(p)
  end

  def self.malloc(size)
    keep(Fiddle::Pointer.malloc(size))
  end
end

def wstr_z(str)
  (str.encode('UTF-16LE') + "\0\0".force_encoding('UTF-16LE')).b
end

def astr_z(str)
  (str.b + "\0").b
end

def create_guid_ptr(d1, d2, d3, d4_bytes)
  Mem.to_ptr([d1, d2, d3, *d4_bytes].pack('LSSC8'))
end

# ============================================================
# C-like mem ops (msvcrt)
# ============================================================
module CRT
  extend Fiddle::Importer
  dlload 'msvcrt.dll'
  extern 'void* memset(void*, int, size_t)'
  extern 'void* memcpy(void*, void*, size_t)'
end

# ============================================================
# Win32 API
# ============================================================
module Win32
  extend Fiddle::Importer
  dlload 'user32.dll', 'kernel32.dll', 'ole32.dll'

  CS_HREDRAW = 0x0002
  CS_VREDRAW = 0x0001
  WS_OVERLAPPEDWINDOW = 0x00CF0000
  CW_USEDEFAULT = -2147483648
  SW_SHOW = 5
  WM_DESTROY = 0x0002
  WM_QUIT = 0x0012
  PM_REMOVE = 0x0001
  IDC_ARROW = 32512
  INFINITE = 0xFFFFFFFF

  RECT = struct(['int left', 'int top', 'int right', 'int bottom'])

  WNDCLASSEX = struct([
    'unsigned int cbSize', 'unsigned int style', 'uintptr_t lpfnWndProc',
    'int cbClsExtra', 'int cbWndExtra', 'uintptr_t hInstance',
    'uintptr_t hIcon', 'uintptr_t hCursor', 'uintptr_t hbrBackground',
    'uintptr_t lpszMenuName', 'uintptr_t lpszClassName', 'uintptr_t hIconSm'
  ])

  MSG = struct([
    'uintptr_t hwnd', 'unsigned int message', 'uintptr_t wParam', 'uintptr_t lParam',
    'unsigned long time', 'long x', 'long y'
  ])

  extern 'uintptr_t GetModuleHandleW(void*)'
  extern 'uintptr_t DefWindowProcW(uintptr_t, unsigned int, uintptr_t, uintptr_t)'
  extern 'unsigned short RegisterClassExW(void*)'
  extern 'uintptr_t CreateWindowExW(unsigned long, const short*, const short*, unsigned long, int, int, int, int, uintptr_t, void*, uintptr_t, void*)'
  extern 'int ShowWindow(uintptr_t, int)'
  extern 'int PeekMessageW(void*, uintptr_t, unsigned int, unsigned int, unsigned int)'
  extern 'int TranslateMessage(void*)'
  extern 'uintptr_t DispatchMessageW(void*)'
  extern 'void PostQuitMessage(int)'
  extern 'uintptr_t LoadCursorW(void*, uintptr_t)'
  extern 'int GetClientRect(uintptr_t, void*)'
  extern 'void Sleep(unsigned long)'
  extern 'void OutputDebugStringW(const short*)'

  extern 'uintptr_t CreateEventW(void*, int, int, const short*)'
  extern 'unsigned long WaitForSingleObject(uintptr_t, unsigned long)'
  extern 'int CloseHandle(uintptr_t)'

  extern 'long CoInitialize(void*)'
  extern 'void CoUninitialize()'
end

# ============================================================
# DX12 exports (dll exports only)
# ============================================================
module DX12
  D3D_FEATURE_LEVEL_12_0 = 0xC000
  DXGI_FORMAT_UNKNOWN            = 0
  DXGI_FORMAT_R8G8B8A8_UNORM     = 28

  DXGI_SWAP_EFFECT_FLIP_DISCARD  = 4
  DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020

  D3D12_COMMAND_LIST_TYPE_DIRECT  = 0
  D3D12_DESCRIPTOR_HEAP_TYPE_RTV  = 2
  D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV = 0
  D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0
  D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 1

  D3D12_RESOURCE_STATE_PRESENT               = 0
  D3D12_RESOURCE_STATE_RENDER_TARGET         = 4
  D3D12_RESOURCE_STATE_COMMON                = 0
  D3D12_RESOURCE_STATE_UNORDERED_ACCESS      = 0x08
  D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE = 0x40
  D3D12_RESOURCE_STATE_GENERIC_READ          = 0x0AC3

  D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE = 2
  D3D_PRIMITIVE_TOPOLOGY_LINESTRIP   = 3

  D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0
  D3D12_RESOURCE_BARRIER_FLAG_NONE       = 0
  D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF

  D3D12_ROOT_SIGNATURE_FLAG_NONE = 0
  D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE = 0

  D3D12_DESCRIPTOR_RANGE_TYPE_SRV = 0
  D3D12_DESCRIPTOR_RANGE_TYPE_UAV = 1
  D3D12_DESCRIPTOR_RANGE_TYPE_CBV = 2

  D3D12_SHADER_VISIBILITY_ALL    = 0
  D3D12_SHADER_VISIBILITY_VERTEX = 1

  D3D12_HEAP_TYPE_DEFAULT  = 1
  D3D12_HEAP_TYPE_UPLOAD   = 2

  D3D12_RESOURCE_FLAG_NONE = 0
  D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS = 0x04
  D3D12_RESOURCE_DIMENSION_BUFFER = 1
  D3D12_TEXTURE_LAYOUT_ROW_MAJOR  = 1

  D3D12_SRV_DIMENSION_BUFFER = 1
  D3D12_UAV_DIMENSION_BUFFER = 1
  D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING = 5768

  D3DCOMPILE_ENABLE_STRICTNESS = 0x00000800

  # ---- COM vtable indices ----
  # ID3D12Device (IUnknown 0-2, ID3D12Object 3-6, then:)
  #   7  = GetNodeCount
  #   8  = CreateCommandQueue
  #   9  = CreateCommandAllocator
  #  10  = CreateGraphicsPipelineState
  #  11  = CreateComputePipelineState
  #  12  = CreateCommandList
  #  13  = CheckFeatureSupport
  #  14  = CreateDescriptorHeap
  #  15  = GetDescriptorHandleIncrementSize
  #  16  = CreateRootSignature
  #  17  = CreateConstantBufferView
  #  18  = CreateShaderResourceView
  #  19  = CreateUnorderedAccessView
  #  20  = CreateRenderTargetView
  #  27  = CreateCommittedResource
  #  36  = CreateFence

  # ID3D12GraphicsCommandList (IUnknown 0-2, ID3D12Object 3-6, ID3D12DeviceChild 7, ID3D12CommandList 8=GetType)
  #   9  = Close
  #  10  = Reset
  #  12  = DrawInstanced
  #  14  = Dispatch
  #  20  = IASetPrimitiveTopology
  #  21  = RSSetViewports
  #  22  = RSSetScissorRects
  #  26  = ResourceBarrier
  #  28  = SetDescriptorHeaps
  #  29  = SetComputeRootSignature
  #  30  = SetGraphicsRootSignature
  #  31  = SetComputeRootDescriptorTable
  #  32  = SetGraphicsRootDescriptorTable
  #  46  = OMSetRenderTargets
  #  48  = ClearRenderTargetView

  # ID3D12Resource (IUnknown 0-2, ID3D12Object 3-6, ID3D12DeviceChild 7)
  #   8  = Map
  #   9  = Unmap
  #  11  = GetGPUVirtualAddress

  # ID3D12DescriptorHeap
  #   9  = GetCPUDescriptorHandleForHeapStart (sret)
  #  10  = GetGPUDescriptorHandleForHeapStart (sret)

  # ID3D12CommandQueue
  #  10  = ExecuteCommandLists
  #  14  = Signal

  # ID3D12Fence
  #   8  = GetCompletedValue
  #   9  = SetEventOnCompletion

  H_D3D12 = Fiddle.dlopen('d3d12.dll')
  H_DXGI  = Fiddle.dlopen('dxgi.dll')
  H_COMPILER = begin
    Fiddle.dlopen('d3dcompiler_47.dll')
  rescue Fiddle::DLError
    Fiddle.dlopen('d3dcompiler_43.dll')
  end

  KEEP = []

  def self.to_ffi_arg(x)
    case x
    when nil then 0
    when Integer then x
    when Fiddle::Pointer then x.to_i
    when String
      p = Mem.to_ptr(x)
      KEEP << p
      p.to_i
    else
      x.respond_to?(:to_i) ? x.to_i : x
    end
  end

  def self.bind(handle, func_name, arg_types, ret_type)
    addr = handle[func_name]
    fn = Fiddle::Function.new(addr, arg_types, ret_type)
    define_singleton_method(func_name) do |*args|
      fn.call(*args.map { |a| to_ffi_arg(a) })
    end
  rescue Fiddle::DLError
  end

  bind(H_D3D12, 'D3D12CreateDevice',
       [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
  bind(H_D3D12, 'D3D12GetDebugInterface',
       [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
  bind(H_D3D12, 'D3D12SerializeRootSignature',
       [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
  bind(H_DXGI, 'CreateDXGIFactory1',
       [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
  bind(H_COMPILER, 'D3DCompile',
       [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP,
        Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP,
        Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP,
        Fiddle::TYPE_INT, Fiddle::TYPE_INT,
        Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
end

# ============================================================
# COM helper
# ============================================================
module COM
  def self.call(obj, index, ret_type, arg_types, *args)
    raise "COM.call: obj is nil/0" if obj.nil? || obj == 0

    p_obj = Fiddle::Pointer.new(obj.to_i)
    vtbl  = p_obj[0, 8].unpack1('Q')
    vptr  = Fiddle::Pointer.new(vtbl)

    fn_addr = vptr[index * 8, 8].unpack1('Q')
    fn = Fiddle::Function.new(fn_addr, [Fiddle::TYPE_VOIDP] + arg_types, ret_type)

    real = args.map do |a|
      if a.nil? then 0
      elsif a.is_a?(Fiddle::Pointer) then a.to_i
      elsif a.respond_to?(:to_i) then a.to_i
      else a
      end
    end

    fn.call(obj.to_i, *real)
  end

  def self.release(obj)
    return if obj.nil? || obj == 0
    call(obj, 2, Fiddle::TYPE_INT, [])
  end

  def self.blob_ptr(blob)
    call(blob, 3, Fiddle::TYPE_LONG_LONG, [])
  end

  def self.blob_size(blob)
    call(blob, 4, Fiddle::TYPE_SIZE_T, [])
  end

  # sret 8 bytes: GetCPUDescriptorHandleForHeapStart / GetGPUDescriptorHandleForHeapStart
  def self.call_sret8(obj, index, arg_types = [], *args)
    out = Mem.malloc(8)
    call(obj, index, Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP] + arg_types, out, *args)
    out[0, 8].unpack1('Q')
  end
end

# ============================================================
# GUIDs
# ============================================================
IID_ID3D12Debug               = create_guid_ptr(0x344488b7, 0x6846, 0x474b, [0xb9, 0x89, 0xf0, 0x27, 0x44, 0x82, 0x45, 0xe0])
IID_IDXGIFactory4             = create_guid_ptr(0x1bc6ea02, 0xef36, 0x464f, [0xbf, 0x0c, 0x21, 0xca, 0x39, 0xe5, 0x16, 0x8a])
IID_ID3D12Device              = create_guid_ptr(0x189819f1, 0x1db6, 0x4b57, [0xbe, 0x54, 0x18, 0x21, 0x33, 0x9b, 0x85, 0xf7])
IID_ID3D12CommandQueue        = create_guid_ptr(0x0ec870a6, 0x5d7e, 0x4c22, [0x8c, 0xfc, 0x5b, 0xaa, 0xe0, 0x76, 0x16, 0xed])
IID_IDXGISwapChain3           = create_guid_ptr(0x94d99bdb, 0xf1f8, 0x4ab0, [0xb2, 0x36, 0x7d, 0xa0, 0x17, 0x0e, 0xda, 0xb1])
IID_ID3D12DescriptorHeap      = create_guid_ptr(0x8efb471d, 0x616c, 0x4f49, [0x90, 0xf7, 0x12, 0x7b, 0xb7, 0x63, 0xfa, 0x51])
IID_ID3D12Resource            = create_guid_ptr(0x696442be, 0xa72e, 0x4059, [0xbc, 0x79, 0x5b, 0x5c, 0x98, 0x04, 0x0f, 0xad])
IID_ID3D12CommandAllocator    = create_guid_ptr(0x6102dee4, 0xaf59, 0x4b09, [0xb9, 0x99, 0xb4, 0x4d, 0x73, 0xf0, 0x9b, 0x24])
IID_ID3D12RootSignature       = create_guid_ptr(0xc54a6b66, 0x72df, 0x4ee8, [0x8b, 0xe5, 0xa9, 0x46, 0xa1, 0x42, 0x92, 0x14])
IID_ID3D12PipelineState       = create_guid_ptr(0x765a30f3, 0xf624, 0x4c6f, [0xa8, 0x28, 0xac, 0xe9, 0x48, 0x62, 0x24, 0x45])
IID_ID3D12GraphicsCommandList = create_guid_ptr(0x5b160d0f, 0xac1b, 0x4185, [0x8b, 0xa8, 0xb3, 0xae, 0x42, 0xa5, 0xa4, 0x55])
IID_ID3D12Fence               = create_guid_ptr(0x0a753dcf, 0xc4d8, 0x4b91, [0xad, 0xf6, 0xbe, 0x5a, 0x60, 0xd9, 0x5a, 0x76])

# ============================================================
# HLSL
# ============================================================
HLSL_SRC = File.read(File.join(File.dirname(__FILE__), 'hello.hlsl'))

# ============================================================
# Constants
# ============================================================
FRAME_COUNT  = 2
MAX_VERTICES = 100_000
PI2          = Math::PI * 2.0

# ============================================================
# Globals
# ============================================================
$factory = 0
$device  = 0
$command_queue = 0
$swap_chain = 0

$rtv_heap = 0
$rtv_descriptor_size = 0
$render_targets = []
$frame_index = 0

$srv_uav_heap = 0
$srv_uav_descriptor_size = 0

$position_buffer = 0
$color_buffer    = 0
$constant_buffer = 0
$constant_buffer_ptr = 0  # persistently mapped

$graphics_allocator = 0
$compute_allocator  = 0
$graphics_list = 0
$compute_list  = 0

$graphics_root_signature = 0
$compute_root_signature  = 0
$graphics_pipeline_state = 0
$compute_pipeline_state  = 0

$fence       = 0
$fence_event = 0
$fence_value = 1

$hwnd   = 0
$width  = 640
$height = 480

# Animation state (matching Python/Perl)
$param_A1 = 50.0; $param_f1 = 2.0;  $param_p1 = 1.0/16.0;  $param_d1 = 0.02
$param_A2 = 50.0; $param_f2 = 2.0;  $param_p2 = 3.0/2.0;   $param_d2 = 0.0315
$param_A3 = 50.0; $param_f3 = 2.0;  $param_p3 = 13.0/15.0;  $param_d3 = 0.02
$param_A4 = 50.0; $param_f4 = 2.0;  $param_p4 = 1.0;        $param_d4 = 0.02

def log(msg)
  puts "[RubyDX12] #{msg}"
end

def hr_hex(hr)
  format("0x%08X", (hr.to_i & 0xFFFFFFFF))
end

def hr_check(hr, what)
  raise "#{what} failed (hr=#{hr_hex(hr)})" if hr != 0
end

# ============================================================
# Debug layer
# ============================================================
def enable_debug_layer
  return unless DX12.respond_to?(:D3D12GetDebugInterface)
  dbg_pp = Mem.malloc(8)
  hr = DX12.D3D12GetDebugInterface(IID_ID3D12Debug, dbg_pp)
  if hr == 0
    dbg = dbg_pp[0, 8].unpack1('Q')
    COM.call(dbg, 3, Fiddle::TYPE_VOID, [])  # EnableDebugLayer
    COM.release(dbg)
    log "D3D12 Debug Layer enabled"
  end
end

# ============================================================
# Shader compilation
# ============================================================
def compile_hlsl(entry, target)
  code_pp = Mem.malloc(8)
  err_pp  = Mem.malloc(8)
  src_ptr = Mem.to_ptr(HLSL_SRC.b)

  hr = DX12.D3DCompile(
    src_ptr, HLSL_SRC.bytesize,
    Mem.to_ptr(astr_z("hello.hlsl")),
    0, 0,
    Mem.to_ptr(astr_z(entry)),
    Mem.to_ptr(astr_z(target)),
    DX12::D3DCOMPILE_ENABLE_STRICTNESS, 0,
    code_pp, err_pp
  )

  if hr != 0
    err = err_pp[0, 8].unpack1('Q')
    if err != 0
      p = COM.blob_ptr(err)
      s = COM.blob_size(err)
      log "Shader Error (#{entry}):\n#{Fiddle::Pointer.new(p)[0, s]}"
      COM.release(err)
    end
    raise "D3DCompile(#{entry}) failed (hr=#{hr_hex(hr)})"
  end

  code_pp[0, 8].unpack1('Q')
end

# ============================================================
# Resource barrier helper
# ============================================================
def make_transition_barrier_bytes(resource, before_state, after_state)
  # D3D12_RESOURCE_BARRIER: 32 bytes on x64
  # Type(L) + Flags(L) + pResource(Q) + Subresource(L) + StateBefore(L) + StateAfter(L) + pad(L)
  [
    DX12::D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
    DX12::D3D12_RESOURCE_BARRIER_FLAG_NONE,
    resource,
    DX12::D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
    before_state,
    after_state,
    0
  ].pack('LLQLLLL')
end

# ============================================================
# Create committed resource (vtable index 27)
# ============================================================
def create_committed_resource(heap_type, size, flags, initial_state)
  # D3D12_HEAP_PROPERTIES (20 bytes)
  heap_props = Mem.to_ptr([heap_type, 0, 0, 1, 1].pack('LLLLL'))

  # D3D12_RESOURCE_DESC (56 bytes on x64)
  # Dimension(L) + pad(4) + Alignment(Q) + Width(Q) + Height(L) +
  # DepthOrArraySize(S) + MipLevels(S) + Format(L) +
  # SampleCount(L) + SampleQuality(L) + Layout(L) + Flags(L) + pad(4)
  res_desc = Mem.to_ptr([
    DX12::D3D12_RESOURCE_DIMENSION_BUFFER,  # Dimension
    0,                                       # Alignment (UINT64)
    size,                                    # Width (UINT64)
    1,                                       # Height
    1, 1,                                    # DepthOrArraySize, MipLevels
    DX12::DXGI_FORMAT_UNKNOWN,              # Format
    1, 0,                                    # SampleDesc (Count=1, Quality=0)
    DX12::D3D12_TEXTURE_LAYOUT_ROW_MAJOR,   # Layout
    flags                                    # Flags
  ].pack('Lx4QQLSSLLLLLx4'))

  res_pp = Mem.malloc(8)
  # ID3D12Device::CreateCommittedResource = vtable index 27
  hr = COM.call(
    $device, 27, Fiddle::TYPE_INT,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT,
     Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT,
     Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    heap_props, 0, res_desc, initial_state, 0, IID_ID3D12Resource, res_pp
  )
  hr_check(hr, "CreateCommittedResource (size=#{size}, flags=#{flags})")
  res_pp[0, 8].unpack1('Q')
end

# ============================================================
# Descriptor creation helpers
# ============================================================
def create_uav(resource, num_elements, heap_offset)
  # D3D12_UNORDERED_ACCESS_VIEW_DESC for structured buffer (40 bytes)
  # Format(L) + ViewDimension(L) + FirstElement(Q) + NumElements(L) +
  # StructureByteStride(L) + CounterOffsetInBytes(Q) + Flags(L) + pad(4)
  desc = Mem.to_ptr([
    DX12::DXGI_FORMAT_UNKNOWN,       # Format (UNKNOWN for structured)
    DX12::D3D12_UAV_DIMENSION_BUFFER, # ViewDimension = BUFFER (1)
    0,                                # FirstElement (UINT64)
    num_elements,                     # NumElements
    16,                               # StructureByteStride (float4=16)
    0,                                # CounterOffsetInBytes (UINT64)
    0                                 # Flags
  ].pack('LLQLLQLx4'))

  handle = COM.call_sret8($srv_uav_heap, 9)  # GetCPUDescriptorHandleForHeapStart
  handle += heap_offset * $srv_uav_descriptor_size

  # ID3D12Device::CreateUnorderedAccessView = vtable index 19
  # (pResource, pCounterResource, pDesc, DestDescriptor)
  COM.call($device, 19, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
           resource, 0, desc, handle)
end

def create_srv(resource, num_elements, heap_offset)
  # D3D12_SHADER_RESOURCE_VIEW_DESC for structured buffer (40 bytes)
  # Format(L) + ViewDimension(L) + Shader4ComponentMapping(L) + pad(4) +
  # FirstElement(Q) + NumElements(L) + StructureByteStride(L) + Flags(L) + pad(4)
  desc = Mem.to_ptr([
    DX12::DXGI_FORMAT_UNKNOWN,        # Format
    DX12::D3D12_SRV_DIMENSION_BUFFER, # ViewDimension = BUFFER (1)
    DX12::D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
    0,                                # FirstElement (UINT64)
    num_elements,                     # NumElements
    16,                               # StructureByteStride
    0                                 # Flags
  ].pack('LLLx4QLLLx4'))

  handle = COM.call_sret8($srv_uav_heap, 9)
  handle += heap_offset * $srv_uav_descriptor_size

  # ID3D12Device::CreateShaderResourceView = vtable index 18
  # (pResource, pDesc, DestDescriptor)
  COM.call($device, 18, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
           resource, desc, handle)
end

def create_cbv(buffer, heap_offset)
  # ID3D12Resource::GetGPUVirtualAddress = vtable index 11
  gpu_addr = COM.call(buffer, 11, Fiddle::TYPE_LONG_LONG, [])

  # D3D12_CONSTANT_BUFFER_VIEW_DESC (16 bytes)
  # BufferLocation(Q) + SizeInBytes(L) + pad(4)
  desc = Mem.to_ptr([gpu_addr, 256].pack('QLx4'))

  handle = COM.call_sret8($srv_uav_heap, 9)
  handle += heap_offset * $srv_uav_descriptor_size

  # ID3D12Device::CreateConstantBufferView = vtable index 17
  # (pDesc, DestDescriptor)
  COM.call($device, 17, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
           desc, handle)
end

# ============================================================
# Root signature creation
# ============================================================
def create_root_signature_with_tables(range_type, range_count, base_register, visibility, label)
  # D3D12_DESCRIPTOR_RANGE (20 bytes each)
  range1 = [range_type, range_count, base_register, 0, 0xFFFFFFFF].pack('LLLLL')
  range1_ptr = Mem.to_ptr(range1)

  cbv_range = [DX12::D3D12_DESCRIPTOR_RANGE_TYPE_CBV, 1, 0, 0, 0xFFFFFFFF].pack('LLLLL')
  cbv_range_ptr = Mem.to_ptr(cbv_range)

  # D3D12_ROOT_PARAMETER (32 bytes each on x64)
  # ParameterType(L) + pad(4) + NumRanges(L) + pad(4) + pRanges(Q) + ShaderVisibility(L) + pad(4)
  param0 = [
    DX12::D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
    1, range1_ptr.to_i,
    visibility
  ].pack('Lx4Lx4QLx4')

  param1 = [
    DX12::D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
    1, cbv_range_ptr.to_i,
    visibility
  ].pack('Lx4Lx4QLx4')

  params_data = param0 + param1
  params_ptr = Mem.to_ptr(params_data)

  # D3D12_ROOT_SIGNATURE_DESC (40 bytes on x64)
  # NumParameters(L) + pad(4) + pParameters(Q) + NumStaticSamplers(L) + pad(4) + pStaticSamplers(Q) + Flags(L) + pad(4)
  rs_desc = Mem.to_ptr([
    2, params_ptr.to_i,
    0, 0,
    DX12::D3D12_ROOT_SIGNATURE_FLAG_NONE
  ].pack('Lx4QLx4QLx4'))

  rs_blob_pp = Mem.malloc(8)
  rs_err_pp  = Mem.malloc(8)
  hr = DX12.D3D12SerializeRootSignature(rs_desc, 1, rs_blob_pp, rs_err_pp)
  if hr != 0
    err = rs_err_pp[0, 8].unpack1('Q')
    if err != 0
      p = COM.blob_ptr(err)
      s = COM.blob_size(err)
      log "RootSig error (#{label}): #{Fiddle::Pointer.new(p)[0, s]}"
      COM.release(err)
    end
    raise "D3D12SerializeRootSignature(#{label}) failed (hr=#{hr_hex(hr)})"
  end

  rs_blob = rs_blob_pp[0, 8].unpack1('Q')
  rs_ptr  = COM.blob_ptr(rs_blob)
  rs_size = COM.blob_size(rs_blob)

  rs_out_pp = Mem.malloc(8)
  # ID3D12Device::CreateRootSignature = vtable index 16
  hr = COM.call($device, 16, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T,
                 Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, rs_ptr, rs_size, IID_ID3D12RootSignature, rs_out_pp)
  COM.release(rs_blob)
  hr_check(hr, "CreateRootSignature(#{label})")
  log "#{label} root signature created"
  rs_out_pp[0, 8].unpack1('Q')
end

# ============================================================
# GPU sync
# ============================================================
def wait_for_gpu
  return if $fence == 0 || $fence_event == 0
  val = $fence_value

  # ID3D12CommandQueue::Signal = vtable index 14
  COM.call($command_queue, 14, Fiddle::TYPE_INT,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG],
           $fence, val)
  $fence_value += 1

  # ID3D12Fence::GetCompletedValue = vtable index 8
  completed = COM.call($fence, 8, Fiddle::TYPE_LONG_LONG, [])
  if completed < val
    # ID3D12Fence::SetEventOnCompletion = vtable index 9
    COM.call($fence, 9, Fiddle::TYPE_INT,
             [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_VOIDP],
             val, $fence_event)
    Win32.WaitForSingleObject($fence_event, Win32::INFINITE)
  end

  # IDXGISwapChain3::GetCurrentBackBufferIndex = vtable index 36
  $frame_index = COM.call($swap_chain, 36, Fiddle::TYPE_INT, [])
end

# ============================================================
# Build constant buffer data (96 bytes matching HLSL cbuffer)
# ============================================================
def build_params_data
  [
    $param_A1, $param_f1, $param_p1, $param_d1,
    $param_A2, $param_f2, $param_p2, $param_d2,
    $param_A3, $param_f3, $param_p3, $param_d3,
    $param_A4, $param_f4, $param_p4, $param_d4,
    MAX_VERTICES,                        # max_num (uint)
    0.0, 0.0, 0.0,                       # padding (float3)
    $width.to_f, $height.to_f,           # resolution (float2)
    0.0, 0.0                             # padding2 (float2)
  ].pack('f16Lffffff')
end

# ============================================================
# init_d3d
# ============================================================
def init_d3d
  enable_debug_layer

  rc = Win32::RECT.malloc
  Win32.GetClientRect($hwnd, rc)
  $width  = rc.right - rc.left
  $height = rc.bottom - rc.top

  # Factory
  log "CreateDXGIFactory1"
  f_pp = Mem.malloc(8)
  hr = DX12.CreateDXGIFactory1(IID_IDXGIFactory4, f_pp)
  hr_check(hr, "CreateDXGIFactory1")
  $factory = f_pp[0, 8].unpack1('Q')

  # Device
  log "D3D12CreateDevice"
  d_pp = Mem.malloc(8)
  hr = DX12.D3D12CreateDevice(0, DX12::D3D_FEATURE_LEVEL_12_0, IID_ID3D12Device, d_pp)
  hr_check(hr, "D3D12CreateDevice")
  $device = d_pp[0, 8].unpack1('Q')

  # Single DIRECT command queue (used for both compute and graphics)
  log "CreateCommandQueue"
  q_desc = Mem.to_ptr([DX12::D3D12_COMMAND_LIST_TYPE_DIRECT, 0, 0, 0].pack('LLLL'))
  cq_pp = Mem.malloc(8)
  hr = COM.call($device, 8, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                q_desc, IID_ID3D12CommandQueue, cq_pp)
  hr_check(hr, "CreateCommandQueue")
  $command_queue = cq_pp[0, 8].unpack1('Q')

  # SwapChain
  log "CreateSwapChainForHwnd"
  sc_desc = Mem.to_ptr([
    $width, $height,
    DX12::DXGI_FORMAT_R8G8B8A8_UNORM,
    0, 1, 0,
    DX12::DXGI_USAGE_RENDER_TARGET_OUTPUT,
    FRAME_COUNT,
    0,
    DX12::DXGI_SWAP_EFFECT_FLIP_DISCARD,
    0, 0
  ].pack('LLLiLLLLLLLL'))

  sc_tmp_pp = Mem.malloc(8)
  hr = COM.call($factory, 15, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP,
                 Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $command_queue, $hwnd, sc_desc, 0, 0, sc_tmp_pp)
  hr_check(hr, "CreateSwapChainForHwnd")

  tmp_swap = sc_tmp_pp[0, 8].unpack1('Q')
  sc3_pp = Mem.malloc(8)
  hr = COM.call(tmp_swap, 0, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                IID_IDXGISwapChain3, sc3_pp)
  COM.release(tmp_swap)
  hr_check(hr, "QueryInterface IDXGISwapChain3")
  $swap_chain = sc3_pp[0, 8].unpack1('Q')
  $frame_index = COM.call($swap_chain, 36, Fiddle::TYPE_INT, [])

  # RTV heap
  log "CreateDescriptorHeap (RTV)"
  rtv_heap_desc = Mem.to_ptr([DX12::D3D12_DESCRIPTOR_HEAP_TYPE_RTV, FRAME_COUNT,
                               DX12::D3D12_DESCRIPTOR_HEAP_FLAG_NONE, 0].pack('LLLL'))
  rtv_pp = Mem.malloc(8)
  hr = COM.call($device, 14, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                rtv_heap_desc, IID_ID3D12DescriptorHeap, rtv_pp)
  hr_check(hr, "CreateDescriptorHeap (RTV)")
  $rtv_heap = rtv_pp[0, 8].unpack1('Q')
  $rtv_descriptor_size = COM.call($device, 15, Fiddle::TYPE_INT,
                                  [Fiddle::TYPE_INT], DX12::D3D12_DESCRIPTOR_HEAP_TYPE_RTV)

  # SRV/UAV/CBV heap (shader-visible, 5 slots: UAV*2 + SRV*2 + CBV*1)
  log "CreateDescriptorHeap (SRV/UAV/CBV)"
  srv_uav_desc = Mem.to_ptr([DX12::D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV, 5,
                              DX12::D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE, 0].pack('LLLL'))
  srv_uav_pp = Mem.malloc(8)
  hr = COM.call($device, 14, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                srv_uav_desc, IID_ID3D12DescriptorHeap, srv_uav_pp)
  hr_check(hr, "CreateDescriptorHeap (SRV/UAV/CBV)")
  $srv_uav_heap = srv_uav_pp[0, 8].unpack1('Q')
  $srv_uav_descriptor_size = COM.call($device, 15, Fiddle::TYPE_INT,
                                      [Fiddle::TYPE_INT], DX12::D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV)
  log "SRV/UAV/CBV descriptor size=#{$srv_uav_descriptor_size}"

  # Create RTVs
  log "Create RTVs"
  rtv_start = COM.call_sret8($rtv_heap, 9)
  FRAME_COUNT.times do |i|
    res_pp = Mem.malloc(8)
    hr = COM.call($swap_chain, 9, Fiddle::TYPE_INT,
                  [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  i, IID_ID3D12Resource, res_pp)
    hr_check(hr, "GetBuffer(#{i})")
    rt = res_pp[0, 8].unpack1('Q')
    $render_targets << rt

    handle = rtv_start + (i * $rtv_descriptor_size)
    # ID3D12Device::CreateRenderTargetView = vtable index 20
    COM.call($device, 20, Fiddle::TYPE_VOID,
             [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
             rt, 0, handle)
  end

  # Create buffers
  log "Create buffers"
  buf_size = MAX_VERTICES * 16  # float4 = 16 bytes

  $position_buffer = create_committed_resource(
    DX12::D3D12_HEAP_TYPE_DEFAULT, buf_size,
    DX12::D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
    DX12::D3D12_RESOURCE_STATE_COMMON)

  $color_buffer = create_committed_resource(
    DX12::D3D12_HEAP_TYPE_DEFAULT, buf_size,
    DX12::D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
    DX12::D3D12_RESOURCE_STATE_COMMON)

  # Constant buffer (256-byte aligned, upload heap, persistently mapped)
  $constant_buffer = create_committed_resource(
    DX12::D3D12_HEAP_TYPE_UPLOAD, 256,
    DX12::D3D12_RESOURCE_FLAG_NONE,
    DX12::D3D12_RESOURCE_STATE_GENERIC_READ)

  # Map constant buffer persistently
  mapped_pp = Mem.malloc(8)
  read_range = Mem.to_ptr([0, 0].pack('QQ'))  # D3D12_RANGE{0,0}
  # ID3D12Resource::Map = vtable index 8
  hr = COM.call($constant_buffer, 8, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, read_range, mapped_pp)
  hr_check(hr, "Map(constantBuffer)")
  $constant_buffer_ptr = mapped_pp[0, 8].unpack1('Q')

  # Write initial params
  params = build_params_data
  CRT.memcpy($constant_buffer_ptr, Mem.to_ptr(params), params.bytesize)
  log "Constant buffer mapped at 0x#{$constant_buffer_ptr.to_s(16)}"

  # Create descriptors
  log "Create descriptors"
  create_uav($position_buffer, MAX_VERTICES, 0)  # slot 0: position UAV
  create_uav($color_buffer,    MAX_VERTICES, 1)  # slot 1: color UAV
  create_srv($position_buffer, MAX_VERTICES, 2)  # slot 2: position SRV
  create_srv($color_buffer,    MAX_VERTICES, 3)  # slot 3: color SRV
  create_cbv($constant_buffer, 4)                 # slot 4: CBV
  log "Descriptors created"

  # Root signatures
  log "Create root signatures"
  # Compute: param0=UAV table(u0,u1), param1=CBV table(b0)
  $compute_root_signature = create_root_signature_with_tables(
    DX12::D3D12_DESCRIPTOR_RANGE_TYPE_UAV, 2, 0,
    DX12::D3D12_SHADER_VISIBILITY_ALL, "Compute")

  # Graphics: param0=SRV table(t0,t1), param1=CBV table(b0)
  $graphics_root_signature = create_root_signature_with_tables(
    DX12::D3D12_DESCRIPTOR_RANGE_TYPE_SRV, 2, 0,
    DX12::D3D12_SHADER_VISIBILITY_VERTEX, "Graphics")

  # Compile shaders
  log "Compile shaders"
  cs_blob = compile_hlsl("CSMain", "cs_5_0")
  vs_blob = compile_hlsl("VSMain", "vs_5_0")
  ps_blob = compile_hlsl("PSMain", "ps_5_0")

  cs_ptr  = COM.blob_ptr(cs_blob)
  cs_size = COM.blob_size(cs_blob)
  vs_ptr  = COM.blob_ptr(vs_blob)
  vs_size = COM.blob_size(vs_blob)
  ps_ptr  = COM.blob_ptr(ps_blob)
  ps_size = COM.blob_size(ps_blob)

  # Compute PSO
  log "CreateComputePipelineState"
  # D3D12_COMPUTE_PIPELINE_STATE_DESC (56 bytes)
  # pRootSignature(Q) + CS.ptr(Q) + CS.size(Q) + NodeMask(L) + pad(4) +
  # CachedPSO.ptr(Q) + CachedPSO.size(Q) + Flags(L) + pad(4)
  compute_pso_desc = Mem.to_ptr([
    $compute_root_signature, cs_ptr, cs_size,
    0,    # NodeMask
    0, 0, # CachedPSO (ptr, size)
    0     # Flags
  ].pack('QQQLx4QQLx4'))

  pso_pp = Mem.malloc(8)
  # ID3D12Device::CreateComputePipelineState = vtable index 11
  hr = COM.call($device, 11, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                compute_pso_desc, IID_ID3D12PipelineState, pso_pp)
  hr_check(hr, "CreateComputePipelineState")
  $compute_pipeline_state = pso_pp[0, 8].unpack1('Q')

  # Graphics PSO (656 bytes)
  log "CreateGraphicsPipelineState"
  pso_desc = Mem.malloc(656)
  CRT.memset(pso_desc, 0, 656)

  # pRootSignature at 0
  CRT.memcpy(pso_desc + 0, Mem.to_ptr([$graphics_root_signature].pack('Q')), 8)
  # VS at 8
  CRT.memcpy(pso_desc + 8,  Mem.to_ptr([vs_ptr, vs_size].pack('QQ')), 16)
  # PS at 24
  CRT.memcpy(pso_desc + 24, Mem.to_ptr([ps_ptr, ps_size].pack('QQ')), 16)

  # BlendState at 120 (8 for AlphaToCoverage+IndependentBlend, then 8*40 for RenderTarget)
  # RenderTarget[0] at 128 (40 bytes each)
  rt0 = [
    0, 0,                           # BlendEnable, LogicOpEnable
    2, 1, 1,                        # SrcBlend=ONE, DestBlend=ZERO, BlendOp=ADD
    2, 1, 1,                        # SrcBlendAlpha=ONE, DestBlendAlpha=ZERO, BlendOpAlpha=ADD
    5,                              # LogicOp=NOOP
    0x0F                            # RenderTargetWriteMask=ALL
  ].pack('llLLLLLLLC' + 'x3')
  rt0_buf = Mem.malloc(40)
  CRT.memset(rt0_buf, 0, 40)
  CRT.memcpy(rt0_buf, Mem.to_ptr(rt0), [rt0.bytesize, 40].min)
  8.times { |i| CRT.memcpy(pso_desc + 128 + (i * 40), rt0_buf, 40) }

  # SampleMask at 448
  CRT.memcpy(pso_desc + 448, Mem.to_ptr([0xFFFFFFFF].pack('L')), 4)

  # RasterizerState at 452 (44 bytes)
  rast = [
    3,    # FillMode = SOLID
    1,    # CullMode = NONE
    0, 0  # FrontCounterClockwise, DepthBias
  ].pack('LLll') +
  [0.0, 0.0].pack('ff') +  # DepthBiasClamp, SlopeScaledDepthBias
  [1, 0, 0, 0, 0].pack('lllLL')  # DepthClipEnable=1, rest 0
  CRT.memcpy(pso_desc + 452, Mem.to_ptr(rast), rast.bytesize)

  # DepthStencilState at 496 (52 bytes) - leave all zeros (disabled)

  # InputLayout at 552 (16 bytes) - no input layout, using SV_VertexID
  # Already zeroed

  # Note: InputLayout at 552 (4-byte padding after DepthStencilState for 8-byte alignment)
  # InputLayout at 552 (16 bytes) -> 568
  # IBStripCutValue at 568 (4 bytes) -> 572
  # PrimitiveTopologyType at 572 = LINE (2)
  CRT.memcpy(pso_desc + 572, Mem.to_ptr([DX12::D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE].pack('L')), 4)
  # NumRenderTargets at 576
  CRT.memcpy(pso_desc + 576, Mem.to_ptr([1].pack('L')), 4)
  # RTVFormats[0] at 580
  CRT.memcpy(pso_desc + 580, Mem.to_ptr([DX12::DXGI_FORMAT_R8G8B8A8_UNORM].pack('L')), 4)
  # DSVFormat at 612 (0 = UNKNOWN)
  # SampleDesc at 616 (Count=1, Quality=0)
  CRT.memcpy(pso_desc + 616, Mem.to_ptr([1, 0].pack('LL')), 8)

  pso_pp2 = Mem.malloc(8)
  # ID3D12Device::CreateGraphicsPipelineState = vtable index 10
  hr = COM.call($device, 10, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                pso_desc, IID_ID3D12PipelineState, pso_pp2)
  hr_check(hr, "CreateGraphicsPipelineState")
  $graphics_pipeline_state = pso_pp2[0, 8].unpack1('Q')

  COM.release(cs_blob)
  COM.release(vs_blob)
  COM.release(ps_blob)

  # Command allocators (both DIRECT type for single queue)
  log "Create command allocators"
  ca_pp = Mem.malloc(8)
  hr = COM.call($device, 9, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                DX12::D3D12_COMMAND_LIST_TYPE_DIRECT, IID_ID3D12CommandAllocator, ca_pp)
  hr_check(hr, "CreateCommandAllocator (graphics)")
  $graphics_allocator = ca_pp[0, 8].unpack1('Q')

  ca_pp2 = Mem.malloc(8)
  hr = COM.call($device, 9, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                DX12::D3D12_COMMAND_LIST_TYPE_DIRECT, IID_ID3D12CommandAllocator, ca_pp2)
  hr_check(hr, "CreateCommandAllocator (compute)")
  $compute_allocator = ca_pp2[0, 8].unpack1('Q')

  # Command lists
  log "Create command lists"
  cl_pp = Mem.malloc(8)
  # ID3D12Device::CreateCommandList = vtable index 12
  hr = COM.call($device, 12, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP,
                 Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, DX12::D3D12_COMMAND_LIST_TYPE_DIRECT,
                $graphics_allocator, $graphics_pipeline_state,
                IID_ID3D12GraphicsCommandList, cl_pp)
  hr_check(hr, "CreateCommandList (graphics)")
  $graphics_list = cl_pp[0, 8].unpack1('Q')
  COM.call($graphics_list, 9, Fiddle::TYPE_INT, [])  # Close

  cl_pp2 = Mem.malloc(8)
  hr = COM.call($device, 12, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP,
                 Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, DX12::D3D12_COMMAND_LIST_TYPE_DIRECT,
                $compute_allocator, $compute_pipeline_state,
                IID_ID3D12GraphicsCommandList, cl_pp2)
  hr_check(hr, "CreateCommandList (compute)")
  $compute_list = cl_pp2[0, 8].unpack1('Q')
  COM.call($compute_list, 9, Fiddle::TYPE_INT, [])  # Close

  # Fence
  log "CreateFence"
  fence_pp = Mem.malloc(8)
  hr = COM.call($device, 36, Fiddle::TYPE_INT,
                [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_INT,
                 Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, 0, IID_ID3D12Fence, fence_pp)
  hr_check(hr, "CreateFence")
  $fence = fence_pp[0, 8].unpack1('Q')
  $fence_value = 1
  $fence_event = Win32.CreateEventW(0, 0, 0, 0)

  log "Init complete"
end

# ============================================================
# Render
# ============================================================
def render
  # Animate parameters (matching Python/Perl)
  $param_f1 = ($param_f1 + rand / 200.0) % 10.0
  $param_f2 = ($param_f2 + rand / 200.0) % 10.0
  $param_p1 += PI2 * 0.5 / 360.0

  # Update constant buffer
  params = build_params_data
  CRT.memcpy($constant_buffer_ptr, Mem.to_ptr(params), params.bytesize)

  # ========== COMPUTE PASS ==========
  # Reset compute allocator & list
  COM.call($compute_allocator, 8, Fiddle::TYPE_INT, [])  # Reset
  COM.call($compute_list, 10, Fiddle::TYPE_INT,           # Reset
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $compute_allocator, $compute_pipeline_state)

  # Set descriptor heaps (vtable 28)
  heap_arr = Mem.to_ptr([$srv_uav_heap].pack('Q'))
  COM.call($compute_list, 28, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, heap_arr)

  # Set compute root signature (vtable 29)
  COM.call($compute_list, 29, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP], $compute_root_signature)

  # Get GPU descriptor handle (vtable 10 on heap - sret)
  gpu_handle = COM.call_sret8($srv_uav_heap, 10)

  # Set compute root descriptor table 0: UAVs at slot 0 (vtable 31)
  COM.call($compute_list, 31, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_LONG_LONG],
           0, gpu_handle)

  # Set compute root descriptor table 1: CBV at slot 4 (vtable 31)
  cbv_gpu = gpu_handle + $srv_uav_descriptor_size * 4
  COM.call($compute_list, 31, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_LONG_LONG],
           1, cbv_gpu)

  # Dispatch (vtable 14)
  num_groups = (MAX_VERTICES + 63) / 64
  COM.call($compute_list, 14, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT],
           num_groups, 1, 1)

  # Barriers: UAV -> SRV
  b1 = make_transition_barrier_bytes($position_buffer,
    DX12::D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
    DX12::D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE)
  b2 = make_transition_barrier_bytes($color_buffer,
    DX12::D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
    DX12::D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE)
  barriers_ptr = Mem.to_ptr(b1 + b2)

  # ResourceBarrier (vtable 26)
  COM.call($compute_list, 26, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           2, barriers_ptr)

  # Close compute list (vtable 9)
  COM.call($compute_list, 9, Fiddle::TYPE_INT, [])

  # Execute compute
  comp_lists = Mem.to_ptr([$compute_list].pack('Q'))
  COM.call($command_queue, 10, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, comp_lists)

  # ========== GRAPHICS PASS ==========
  COM.call($graphics_allocator, 8, Fiddle::TYPE_INT, [])  # Reset
  COM.call($graphics_list, 10, Fiddle::TYPE_INT,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $graphics_allocator, $graphics_pipeline_state)

  # Set descriptor heaps (vtable 28)
  COM.call($graphics_list, 28, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, heap_arr)

  # Set graphics root signature (vtable 30)
  COM.call($graphics_list, 30, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP], $graphics_root_signature)

  # Set graphics root descriptor table 0: SRVs at slot 2 (vtable 32)
  srv_gpu = gpu_handle + $srv_uav_descriptor_size * 2
  COM.call($graphics_list, 32, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_LONG_LONG],
           0, srv_gpu)

  # Set graphics root descriptor table 1: CBV at slot 4 (vtable 32)
  COM.call($graphics_list, 32, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_LONG_LONG],
           1, cbv_gpu)

  # Viewport (vtable 21)
  vp = Mem.to_ptr([0.0, 0.0, $width.to_f, $height.to_f, 0.0, 1.0].pack('ffffff'))
  COM.call($graphics_list, 21, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], 1, vp)

  # Scissor (vtable 22)
  sc = Mem.to_ptr([0, 0, $width, $height].pack('llll'))
  COM.call($graphics_list, 22, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], 1, sc)

  # Barrier: PRESENT -> RENDER_TARGET
  rt = $render_targets[$frame_index]
  rt_barrier_bytes = make_transition_barrier_bytes(rt,
    DX12::D3D12_RESOURCE_STATE_PRESENT,
    DX12::D3D12_RESOURCE_STATE_RENDER_TARGET)
  COM.call($graphics_list, 26, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, Mem.to_ptr(rt_barrier_bytes))

  # Set render target (vtable 46)
  rtv_start = COM.call_sret8($rtv_heap, 9)
  rtv_handle = rtv_start + ($frame_index * $rtv_descriptor_size)
  rtv_ptr = Mem.to_ptr([rtv_handle].pack('Q'))
  COM.call($graphics_list, 46, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, rtv_ptr, 0, 0)

  # Clear RTV (vtable 48) - dark blue
  clear = Mem.to_ptr([0.05, 0.05, 0.1, 1.0].pack('ffff'))
  COM.call($graphics_list, 48, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           rtv_handle, clear, 0, 0)

  # Set topology: LINESTRIP (vtable 20)
  COM.call($graphics_list, 20, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT], DX12::D3D_PRIMITIVE_TOPOLOGY_LINESTRIP)

  # Draw (vtable 12)
  COM.call($graphics_list, 12, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT],
           MAX_VERTICES, 1, 0, 0)

  # Barrier: RENDER_TARGET -> PRESENT
  rt_barrier_bytes2 = make_transition_barrier_bytes(rt,
    DX12::D3D12_RESOURCE_STATE_RENDER_TARGET,
    DX12::D3D12_RESOURCE_STATE_PRESENT)
  COM.call($graphics_list, 26, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, Mem.to_ptr(rt_barrier_bytes2))

  # Barriers: SRV -> UAV (for next frame compute pass)
  b3 = make_transition_barrier_bytes($position_buffer,
    DX12::D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
    DX12::D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
  b4 = make_transition_barrier_bytes($color_buffer,
    DX12::D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
    DX12::D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
  COM.call($graphics_list, 26, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           2, Mem.to_ptr(b3 + b4))

  # Close graphics list
  COM.call($graphics_list, 9, Fiddle::TYPE_INT, [])

  # Execute graphics
  gfx_lists = Mem.to_ptr([$graphics_list].pack('Q'))
  COM.call($command_queue, 10, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, gfx_lists)

  # Present
  COM.call($swap_chain, 8, Fiddle::TYPE_INT,
           [Fiddle::TYPE_INT, Fiddle::TYPE_INT], 1, 0)

  wait_for_gpu
end

# ============================================================
# Cleanup
# ============================================================
def cleanup
  wait_for_gpu rescue nil

  Win32.CloseHandle($fence_event) if $fence_event != 0

  COM.release($fence)
  COM.release($compute_list)
  COM.release($graphics_list)
  COM.release($compute_pipeline_state)
  COM.release($graphics_pipeline_state)
  COM.release($compute_root_signature)
  COM.release($graphics_root_signature)
  COM.release($compute_allocator)
  COM.release($graphics_allocator)

  COM.release($constant_buffer)
  COM.release($color_buffer)
  COM.release($position_buffer)
  COM.release($srv_uav_heap)

  $render_targets.each { |rt| COM.release(rt) }
  COM.release($rtv_heap)
  COM.release($swap_chain)
  COM.release($command_queue)
  COM.release($device)
  COM.release($factory)
end

# ============================================================
# WinMain
# ============================================================
WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  if msg == Win32::WM_DESTROY
    Win32.PostQuitMessage(0)
    0
  else
    Win32.DefWindowProcW(hwnd, msg, wparam, lparam)
  end
end

puts "=== DirectX 12 Harmonograph (Compute Shader / Ruby x64) ==="
Win32.CoInitialize(0)

hInstance = Win32.GetModuleHandleW(0)
cls_name  = Mem.to_ptr(wstr_z("RubyDX12Harmonograph"))

wc = Win32::WNDCLASSEX.malloc
wc.cbSize = Win32::WNDCLASSEX.size
wc.style  = Win32::CS_HREDRAW | Win32::CS_VREDRAW
wc.lpfnWndProc = WndProc.to_i
wc.hInstance = hInstance
wc.hCursor   = Win32.LoadCursorW(0, Win32::IDC_ARROW)
wc.lpszClassName = cls_name.to_i
Win32.RegisterClassExW(wc)

$hwnd = Win32.CreateWindowExW(
  0, cls_name,
  Mem.to_ptr(wstr_z("DirectX 12 Harmonograph (Ruby)")),
  Win32::WS_OVERLAPPEDWINDOW,
  Win32::CW_USEDEFAULT, Win32::CW_USEDEFAULT, 800, 600,
  0, 0, hInstance, 0
)
Win32.ShowWindow($hwnd, Win32::SW_SHOW)

begin
  init_d3d

  puts "Entering render loop..."
  msg = Win32::MSG.malloc
  loop do
    if Win32.PeekMessageW(msg, 0, 0, 0, Win32::PM_REMOVE) != 0
      break if msg.message == Win32::WM_QUIT
      Win32.TranslateMessage(msg)
      Win32.DispatchMessageW(msg)
    else
      render
    end
  end
ensure
  cleanup
  Win32.CoUninitialize
  puts "Done"
end
