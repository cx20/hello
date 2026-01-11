# hello.rb (Ruby 3.3 x64 / Fiddle only) - DirectX 12 draw triangle
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
  # --- feature/format
  D3D_FEATURE_LEVEL_12_0 = 0xC000
  DXGI_FORMAT_R8G8B8A8_UNORM = 28

  DXGI_SWAP_EFFECT_FLIP_DISCARD = 4
  DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020

  D3D12_COMMAND_LIST_TYPE_DIRECT = 0
  D3D12_DESCRIPTOR_HEAP_TYPE_RTV = 2
  D3D12_DESCRIPTOR_HEAP_FLAG_NONE = 0

  D3D12_RESOURCE_STATE_PRESENT = 0
  D3D12_RESOURCE_STATE_RENDER_TARGET = 4

  D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE = 3
  D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4

  # resource barrier
  D3D12_RESOURCE_BARRIER_TYPE_TRANSITION = 0
  D3D12_RESOURCE_BARRIER_FLAG_NONE = 0
  D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF

  # root signature
  D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1

  # shader compile
  D3DCOMPILE_ENABLE_STRICTNESS = 0x00000002

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
    when nil
      0
    when Integer
      x
    when Fiddle::Pointer
      x.to_i
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
      if a.nil?
        0
      elsif a.is_a?(Fiddle::Pointer)
        a.to_i
      elsif a.respond_to?(:to_i)
        a.to_i
      else
        a
      end
    end

    fn.call(obj.to_i, *real)
  end

  def self.release(obj)
    return if obj.nil? || obj == 0
    call(obj, 2, Fiddle::TYPE_INT, [])
  end

  # ID3DBlob
  def self.blob_ptr(blob)
    call(blob, 3, Fiddle::TYPE_LONG_LONG, [])
  end

  def self.blob_size(blob)
    call(blob, 4, Fiddle::TYPE_SIZE_T, [])
  end

  # ★ sret 8 bytes: D3D12_CPU_DESCRIPTOR_HANDLE etc
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
# HLSL (no vertex buffer: SV_VertexID)
# ============================================================
HLSL_SRC = <<~HLSL
  struct PSInput { float4 position : SV_POSITION; float4 color : COLOR0; };

  PSInput VS(uint vid : SV_VertexID)
  {
      float2 pos[3] = { float2(0.0, 0.5), float2(0.5, -0.5), float2(-0.5, -0.5) };
      float4 col[3] = { float4(1,0,0,1), float4(0,1,0,1), float4(0,0,1,1) };
      PSInput o;
      o.position = float4(pos[vid], 0.0, 1.0);
      o.color = col[vid];
      return o;
  }

  float4 PS(PSInput i) : SV_Target
  {
      return i.color;
  }
HLSL

# ============================================================
# Globals
# ============================================================
FRAME_COUNT = 2

$factory = 0
$device = 0
$command_queue = 0
$swap_chain = 0

$rtv_heap = 0
$rtv_descriptor_size = 0
$rtv_heap_start = 0
$render_targets = []
$frame_index = 0

$command_allocator = 0
$command_list = 0
$root_signature = 0
$pipeline_state = 0

$fence = 0
$fence_event = 0
$fence_value = 1

$hwnd = 0
$width = 640
$height = 480

def log(msg)
  puts "[RubyDX12] #{msg}"
  Win32.OutputDebugStringW(Mem.to_ptr(wstr_z("[RubyDX12] #{msg}\n")))
end

def hr_hex(hr)
  format("0x%08X", (hr.to_i & 0xFFFFFFFF))
end

def hr_check(hr, what)
  raise "#{what} failed (hr=#{hr_hex(hr)})" if hr != 0
end

def enable_debug_layer
  return unless DX12.respond_to?(:D3D12GetDebugInterface)
  dbg_pp = Mem.malloc(8)
  hr = DX12.D3D12GetDebugInterface(IID_ID3D12Debug, dbg_pp)
  if hr == 0
    dbg = dbg_pp[0, 8].unpack1('Q')
    COM.call(dbg, 3, Fiddle::TYPE_VOID, []) # EnableDebugLayer
    COM.release(dbg)
    log "D3D12 Debug Layer enabled"
  else
    log "D3D12GetDebugInterface failed (hr=#{hr_hex(hr)})"
  end
end

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
      log "Shader Compile Error:\n#{Fiddle::Pointer.new(p)[0, s]}"
      COM.release(err)
    end
    raise "D3DCompile failed (hr=#{hr_hex(hr)})"
  end

  code_pp[0, 8].unpack1('Q') # ID3DBlob*
end

def make_transition_barrier(resource, before_state, after_state)
  # D3D12_RESOURCE_BARRIER (32 bytes) transition
  # pack: Type, Flags, pResource, Subresource, StateBefore, StateAfter, pad
  Mem.to_ptr([
    DX12::D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
    DX12::D3D12_RESOURCE_BARRIER_FLAG_NONE,
    resource,
    DX12::D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
    before_state,
    after_state,
    0
  ].pack('LLQLLLL'))
end

def wait_for_gpu
  # CommandQueue::Signal (index 14)
  COM.call($command_queue, 14, Fiddle::TYPE_INT,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG],
           $fence, $fence_value)
  # Fence::SetEventOnCompletion (index 9)
  COM.call($fence, 9, Fiddle::TYPE_INT,
           [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_VOIDP],
           $fence_value, $fence_event)
  Win32.WaitForSingleObject($fence_event, Win32::INFINITE)
  $fence_value += 1
end

def init_d3d
  enable_debug_layer

  # window size
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

  # CommandQueue (ID3D12Device::CreateCommandQueue index 8)
  log "CreateCommandQueue"
  q_desc = Mem.to_ptr([DX12::D3D12_COMMAND_LIST_TYPE_DIRECT, 0, 0, 0].pack('LLLL'))
  cq_pp  = Mem.malloc(8)
  hr = COM.call($device, 8, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                q_desc, IID_ID3D12CommandQueue, cq_pp)
  hr_check(hr, "CreateCommandQueue")
  $command_queue = cq_pp[0, 8].unpack1('Q')

  # SwapChain (IDXGIFactory4::CreateSwapChainForHwnd index 15)
  log "CreateSwapChainForHwnd"
  sc_desc = Mem.to_ptr([
    $width, $height,
    DX12::DXGI_FORMAT_R8G8B8A8_UNORM,
    0,          # Stereo
    1, 0,       # SampleDesc Count/Quality
    DX12::DXGI_USAGE_RENDER_TARGET_OUTPUT,
    FRAME_COUNT,
    0,          # Scaling
    DX12::DXGI_SWAP_EFFECT_FLIP_DISCARD,
    0,          # AlphaMode
    0           # Flags
  ].pack('LLLiLLLLLLLL'))

  sc_tmp_pp = Mem.malloc(8)
  hr = COM.call($factory, 15, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $command_queue, $hwnd, sc_desc, 0, 0, sc_tmp_pp)
  hr_check(hr, "CreateSwapChainForHwnd")

  tmp_swap = sc_tmp_pp[0, 8].unpack1('Q')
  sc3_pp = Mem.malloc(8)
  hr = COM.call(tmp_swap, 0, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                IID_IDXGISwapChain3, sc3_pp)
  COM.release(tmp_swap)
  hr_check(hr, "SwapChain QueryInterface")
  $swap_chain = sc3_pp[0, 8].unpack1('Q')

  $frame_index = COM.call($swap_chain, 36, Fiddle::TYPE_INT, [])
  log "FrameIndex=#{$frame_index}"

  # RTV heap (ID3D12Device::CreateDescriptorHeap index 14)
  log "CreateDescriptorHeap (RTV)"
  rtv_heap_desc = Mem.to_ptr([DX12::D3D12_DESCRIPTOR_HEAP_TYPE_RTV, FRAME_COUNT, DX12::D3D12_DESCRIPTOR_HEAP_FLAG_NONE, 0].pack('LLLL'))
  rtv_pp = Mem.malloc(8)
  hr = COM.call($device, 14, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                rtv_heap_desc, IID_ID3D12DescriptorHeap, rtv_pp)
  hr_check(hr, "CreateDescriptorHeap")
  $rtv_heap = rtv_pp[0, 8].unpack1('Q')

  # ID3D12Device::GetDescriptorHandleIncrementSize index 15
  $rtv_descriptor_size = COM.call($device, 15, Fiddle::TYPE_INT, [Fiddle::TYPE_INT], DX12::D3D12_DESCRIPTOR_HEAP_TYPE_RTV)
  log "RTV descriptor size=#{$rtv_descriptor_size}"

  # ID3D12DescriptorHeap::GetCPUDescriptorHandleForHeapStart index 9 (sret 8)
  $rtv_heap_start = COM.call_sret8($rtv_heap, 9)
  log format("RTV heap start=0x%016X", $rtv_heap_start)

  # Create RTVs (IDXGISwapChain::GetBuffer index 9, ID3D12Device::CreateRenderTargetView index 20)
  log "Create RTVs"
  FRAME_COUNT.times do |i|
    res_pp = Mem.malloc(8)
    hr = COM.call($swap_chain, 9, Fiddle::TYPE_INT,
                  [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  i, IID_ID3D12Resource, res_pp)
    hr_check(hr, "GetBuffer")
    rt = res_pp[0, 8].unpack1('Q')
    $render_targets << rt

    handle = $rtv_heap_start + (i * $rtv_descriptor_size)
    COM.call($device, 20, Fiddle::TYPE_VOID,
             [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T],
             rt, 0, handle)
  end

  # CommandAllocator (ID3D12Device::CreateCommandAllocator index 9)
  log "CreateCommandAllocator"
  ca_pp = Mem.malloc(8)
  hr = COM.call($device, 9, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                DX12::D3D12_COMMAND_LIST_TYPE_DIRECT, IID_ID3D12CommandAllocator, ca_pp)
  hr_check(hr, "CreateCommandAllocator")
  $command_allocator = ca_pp[0, 8].unpack1('Q')

  # RootSignature (serialize + ID3D12Device::CreateRootSignature index 16)
  log "CreateRootSignature"
  # D3D12_ROOT_SIGNATURE_DESC (32 bytes)
  rs_desc = Mem.to_ptr([0, 0, 0, 0, DX12::D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT, 0].pack('LQLQLL'))
  rs_blob_pp = Mem.malloc(8)
  rs_err_pp  = Mem.malloc(8)
  hr = DX12.D3D12SerializeRootSignature(rs_desc, 1, rs_blob_pp, rs_err_pp)
  hr_check(hr, "D3D12SerializeRootSignature")

  rs_blob = rs_blob_pp[0, 8].unpack1('Q')
  rs_ptr  = COM.blob_ptr(rs_blob)
  rs_size = COM.blob_size(rs_blob)

  rs_out_pp = Mem.malloc(8)
  hr = COM.call($device, 16, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, rs_ptr, rs_size, IID_ID3D12RootSignature, rs_out_pp)
  COM.release(rs_blob)
  hr_check(hr, "CreateRootSignature")
  $root_signature = rs_out_pp[0, 8].unpack1('Q')

  # Shaders
  log "Compile shaders"
  vs_blob = compile_hlsl("VS", "vs_5_0")
  ps_blob = compile_hlsl("PS", "ps_5_0")

  vs_ptr  = COM.blob_ptr(vs_blob)
  vs_size = COM.blob_size(vs_blob)
  ps_ptr  = COM.blob_ptr(ps_blob)
  ps_size = COM.blob_size(ps_blob)

  # PSO (ID3D12Device::CreateGraphicsPipelineState index 10)
  log "CreateGraphicsPipelineState"
  pso_desc = Mem.malloc(656)
  CRT.memset(pso_desc, 0, 656)

  # Offsets are for x64 (D3D12_GRAPHICS_PIPELINE_STATE_DESC)
  # pRootSignature @0
  CRT.memcpy(pso_desc + 0,  Mem.to_ptr([$root_signature].pack('Q')), 8)

  # VS bytecode @8, PS bytecode @24
  CRT.memcpy(pso_desc + 8,  Mem.to_ptr([vs_ptr, vs_size].pack('QQ')), 16)
  CRT.memcpy(pso_desc + 24, Mem.to_ptr([ps_ptr, ps_size].pack('QQ')), 16)

  # BlendState @120 (default)
  # AlphaToCoverageEnable=0, IndependentBlendEnable=0 already 0
  # RenderTarget[0] default: WriteMask=0x0F, others: BlendEnable=0 etc + SrcBlend=ONE, DestBlend=ZERO, BlendOp=ADD...
  # D3D12_BLEND: ZERO=1, ONE=2 / D3D12_BLEND_OP_ADD=1
  rt0 = [
    0, 0,         # BlendEnable, LogicOpEnable
    2, 1, 1,      # SrcBlend=ONE, DestBlend=ZERO, BlendOp=ADD
    2, 1, 1,      # SrcBlendAlpha=ONE, DestBlendAlpha=ZERO, BlendOpAlpha=ADD
    0,            # LogicOp (unused when disabled)
    0x0F          # RenderTargetWriteMask
  ].pack('llLLLLLLLC') # will be 37 bytes; copy into first RT entry (40 bytes)
  rt0_buf = Mem.malloc(40)
  CRT.memset(rt0_buf, 0, 40)
  CRT.memcpy(rt0_buf, Mem.to_ptr(rt0), rt0.bytesize)

  # RenderTarget array starts at 120+8, each is 40 bytes. Copy rt0 into all 8 as safe default.
  8.times do |i|
    CRT.memcpy(pso_desc + 120 + 8 + (i * 40), rt0_buf, 40)
  end

  # SampleMask @448 = UINT_MAX
  CRT.memcpy(pso_desc + 448, Mem.to_ptr([0xFFFFFFFF].pack('L')), 4)

  # RasterizerState @452 (default)
  # FillMode=SOLID(3), CullMode=BACK(3), FrontCCW=0, DepthBias=0,
  # DepthBiasClamp=0, SlopeScaled=0, DepthClipEnable=1, Multisample=0, AAline=0, ForcedSampleCount=0, Conservative=0
  rast = [3, 3, 0, 0].pack('LLll') + [0.0, 0.0].pack('ff') + [1, 0, 0].pack('lll') + [0].pack('L') + [0].pack('L')
  # rast should be 44 bytes
  rast_buf = Mem.malloc(44)
  CRT.memset(rast_buf, 0, 44)
  CRT.memcpy(rast_buf, Mem.to_ptr(rast), [rast.bytesize, 44].min)
  CRT.memcpy(pso_desc + 452, rast_buf, 44)

  # DepthStencilState @496 (disable depth/stencil)
  # DepthEnable=0, DepthWriteMask=1, DepthFunc=2(LESS) - ignored, StencilEnable=0, masks 0xFF
  dss = Mem.malloc(52)
  CRT.memset(dss, 0, 52)
  CRT.memcpy(dss + 4,  Mem.to_ptr([1].pack('L')), 4)         # DepthWriteMask
  CRT.memcpy(dss + 8,  Mem.to_ptr([2].pack('L')), 4)         # DepthFunc
  CRT.memcpy(dss + 16, Mem.to_ptr([0xFF].pack('C')), 1)      # StencilReadMask
  CRT.memcpy(dss + 17, Mem.to_ptr([0xFF].pack('C')), 1)      # StencilWriteMask
  CRT.memcpy(pso_desc + 496, dss, 52)

  # InputLayout @552: none (pInputElementDescs=0, NumElements=0)
  # IBStripCutValue @568 = 0
  # PrimitiveTopologyType @572 = TRIANGLE
  CRT.memcpy(pso_desc + 572, Mem.to_ptr([DX12::D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE].pack('L')), 4)

  # NumRenderTargets @576 = 1
  CRT.memcpy(pso_desc + 576, Mem.to_ptr([1].pack('L')), 4)

  # RTVFormats @580: RTVFormats[0] = R8G8B8A8_UNORM
  CRT.memcpy(pso_desc + 580, Mem.to_ptr([DX12::DXGI_FORMAT_R8G8B8A8_UNORM].pack('L')), 4)

  # SampleDesc @616: Count=1, Quality=0
  CRT.memcpy(pso_desc + 616, Mem.to_ptr([1, 0].pack('LL')), 8)

  # Flags @648 = 0 (default)

  pso_pp = Mem.malloc(8)
  hr = COM.call($device, 10, Fiddle::TYPE_INT,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                pso_desc, IID_ID3D12PipelineState, pso_pp)
  COM.release(vs_blob)
  COM.release(ps_blob)
  hr_check(hr, "CreateGraphicsPipelineState")
  $pipeline_state = pso_pp[0, 8].unpack1('Q')

  # CommandList (ID3D12Device::CreateCommandList index 12)
  log "CreateCommandList"
  cl_pp = Mem.malloc(8)
  hr = COM.call($device, 12, Fiddle::TYPE_INT,
                [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, DX12::D3D12_COMMAND_LIST_TYPE_DIRECT, $command_allocator, $pipeline_state, IID_ID3D12GraphicsCommandList, cl_pp)
  hr_check(hr, "CreateCommandList")
  $command_list = cl_pp[0, 8].unpack1('Q')

  # Close it once (ID3D12GraphicsCommandList::Close index 9)
  COM.call($command_list, 9, Fiddle::TYPE_INT, [])

  # Fence (ID3D12Device::CreateFence index 36)
  log "CreateFence"
  fence_pp = Mem.malloc(8)
  hr = COM.call($device, 36, Fiddle::TYPE_INT,
                [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                0, 0, IID_ID3D12Fence, fence_pp)
  hr_check(hr, "CreateFence")
  $fence = fence_pp[0, 8].unpack1('Q')
  $fence_event = Win32.CreateEventW(0, 0, 0, 0)

  log "Init Complete"
end

def render
  # Reset allocator (ID3D12CommandAllocator::Reset index 8)
  COM.call($command_allocator, 8, Fiddle::TYPE_INT, [])

  # Reset command list (ID3D12GraphicsCommandList::Reset index 10)
  COM.call($command_list, 10, Fiddle::TYPE_INT,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $command_allocator, $pipeline_state)

  # Set root signature (index 30)
  COM.call($command_list, 30, Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP], $root_signature)

  # viewport/scissor
  vp = Mem.to_ptr([0.0, 0.0, $width.to_f, $height.to_f, 0.0, 1.0].pack('ffffff'))
  COM.call($command_list, 21, Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], 1, vp)
  sc = Mem.to_ptr([0, 0, $width, $height].pack('l*'))
  COM.call($command_list, 22, Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], 1, sc)

  # barrier: present -> render target
  rt = $render_targets[$frame_index]
  b1 = make_transition_barrier(rt, DX12::D3D12_RESOURCE_STATE_PRESENT, DX12::D3D12_RESOURCE_STATE_RENDER_TARGET)
  COM.call($command_list, 26, Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], 1, b1)

  # current RTV handle
  handle = $rtv_heap_start + ($frame_index * $rtv_descriptor_size)
  handle_ptr = Mem.to_ptr([handle].pack('Q'))

  # OMSetRenderTargets (index 46): (NumRT, pRTs, RTsSingleRange, pDSV)
  COM.call($command_list, 46, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, handle_ptr, 1, 0)

  # ClearRenderTargetView (index 48): first arg is handle-by-value (8 bytes) => pass as 64-bit
  clear = Mem.to_ptr([1.0, 1.0, 1.0, 1.0].pack('ffff'))
  COM.call($command_list, 48, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           handle, clear, 0, 0)

  # IASetPrimitiveTopology (index 20)
  COM.call($command_list, 20, Fiddle::TYPE_VOID, [Fiddle::TYPE_INT], DX12::D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST)

  # DrawInstanced (index 12): 3 vertices, 1 instance
  COM.call($command_list, 12, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT],
           3, 1, 0, 0)

  # barrier: render target -> present
  b2 = make_transition_barrier(rt, DX12::D3D12_RESOURCE_STATE_RENDER_TARGET, DX12::D3D12_RESOURCE_STATE_PRESENT)
  COM.call($command_list, 26, Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], 1, b2)

  # Close
  COM.call($command_list, 9, Fiddle::TYPE_INT, [])

  # ExecuteCommandLists (CommandQueue index 10)
  lists = Mem.to_ptr([$command_list].pack('Q'))
  COM.call($command_queue, 10, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
           1, lists)

  # Present (SwapChain index 8)
  COM.call($swap_chain, 8, Fiddle::TYPE_INT, [Fiddle::TYPE_INT, Fiddle::TYPE_INT], 1, 0)

  # sync (simple: wait every frame)
  wait_for_gpu

  # GetCurrentBackBufferIndex (SwapChain index 36)
  $frame_index = COM.call($swap_chain, 36, Fiddle::TYPE_INT, [])
end

def cleanup
  wait_for_gpu rescue nil

  Win32.CloseHandle($fence_event) if $fence_event != 0

  COM.release($fence)
  COM.release($command_list)
  COM.release($pipeline_state)
  COM.release($root_signature)
  COM.release($command_allocator)

  $render_targets.each { |rt| COM.release(rt) }
  COM.release($rtv_heap)
  COM.release($swap_chain)
  COM.release($command_queue)
  COM.release($device)
  COM.release($factory)
end

# ============================================================
# WinMain-ish
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

puts "=== DirectX 12 Triangle (Ruby x64) ==="
Win32.CoInitialize(0)

hInstance = Win32.GetModuleHandleW(0)
cls_name  = Mem.to_ptr(wstr_z("RubyDX12"))
win_title = Mem.to_ptr(wstr_z("DirectX 12 Triangle (Ruby)"))

wc = Win32::WNDCLASSEX.malloc
wc.cbSize = Win32::WNDCLASSEX.size
wc.style  = Win32::CS_HREDRAW | Win32::CS_VREDRAW
wc.lpfnWndProc = WndProc.to_i
wc.hInstance = hInstance
wc.hCursor   = Win32.LoadCursorW(0, Win32::IDC_ARROW)
wc.lpszClassName = cls_name.to_i
Win32.RegisterClassExW(wc)

$hwnd = Win32.CreateWindowExW(
  0, cls_name, win_title, Win32::WS_OVERLAPPEDWINDOW,
  Win32::CW_USEDEFAULT, Win32::CW_USEDEFAULT, 640, 480,
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
      Win32.Sleep(1)
    end
  end
ensure
  cleanup
  Win32.CoUninitialize
  puts "Done"
end
