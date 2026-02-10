require 'fiddle/import'

# User32.dll
module User32
  extend Fiddle::Importer
  dlload 'user32.dll'
  
  CS_HREDRAW = 0x0002
  CS_VREDRAW = 0x0001
  WS_OVERLAPPEDWINDOW = 0x00CF0000
  CW_USEDEFAULT = -2147483648
  SW_SHOW = 5
  WM_DESTROY = 0x0002
  WM_QUIT = 0x0012
  PM_REMOVE = 0x0001
  IDC_ARROW = 32512
  WM_NCCREATE = 0x0081
  
  typealias 'UINT', 'unsigned int'
  typealias 'DWORD', 'unsigned long'
  typealias 'BOOL', 'int'
  typealias 'UINTPTR', 'uintptr_t'
  typealias 'USHORT', 'unsigned short'
  
  WNDCLASSEX = struct([
    'UINT cbSize', 'UINT style', 'UINTPTR lpfnWndProc',
    'int cbClsExtra', 'int cbWndExtra', 'UINTPTR hInstance',
    'UINTPTR hIcon', 'UINTPTR hCursor', 'UINTPTR hbrBackground',
    'UINTPTR lpszMenuName', 'UINTPTR lpszClassName', 'UINTPTR hIconSm'
  ])
  
  MSG = struct([
    'UINTPTR hwnd', 'UINT message', 'UINTPTR wParam', 'UINTPTR lParam',
    'DWORD time', 'long x', 'long y'
  ])
  
  RECT = struct(['long left', 'long top', 'long right', 'long bottom'])
  
  extern 'USHORT RegisterClassExA(void*)'
  extern 'UINTPTR CreateWindowExA(DWORD, const char*, const char*, DWORD, int, int, int, int, UINTPTR, UINTPTR, UINTPTR, void*)'
  extern 'int ShowWindow(UINTPTR, int)'
  extern 'BOOL PeekMessageA(void*, UINTPTR, UINT, UINT, UINT)'
  extern 'int TranslateMessage(void*)'
  extern 'UINTPTR DispatchMessageA(void*)'
  extern 'void PostQuitMessage(int)'
  extern 'UINTPTR DefWindowProcA(UINTPTR, UINT, UINTPTR, UINTPTR)'
  extern 'UINTPTR LoadCursorA(UINTPTR, UINTPTR)'
  extern 'BOOL GetClientRect(UINTPTR, void*)'
end

# Kernel32.dll
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  
  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'void Sleep(unsigned long)'
end

# Ole32.dll
module Ole32
  extend Fiddle::Importer
  dlload 'ole32.dll'
  
  extern 'long CoInitialize(void*)'
  extern 'void CoUninitialize()'
end

# D3D10.dll
module D3D10
  extend Fiddle::Importer
  dlload 'd3d10.dll'
  
  D3D10_SDK_VERSION = 29
  D3D10_CREATE_DEVICE_DEBUG = 0x00000002
  
  D3D_DRIVER_TYPE_HARDWARE = 1
  D3D_DRIVER_TYPE_WARP = 5
  D3D_DRIVER_TYPE_REFERENCE = 2
  
  DXGI_FORMAT_R8G8B8A8_UNORM = 28
  DXGI_FORMAT_R32G32B32_FLOAT = 6
  DXGI_FORMAT_R32G32B32A32_FLOAT = 2
  DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020
  
  D3D10_USAGE_DEFAULT = 0
  D3D10_BIND_VERTEX_BUFFER = 0x00000001
  D3D10_INPUT_PER_VERTEX_DATA = 0
  D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4
  
  # Rasterizer state
  D3D10_FILL_WIREFRAME = 2
  D3D10_FILL_SOLID = 3
  D3D10_CULL_NONE = 1
  
  typealias 'UINT', 'unsigned int'
  typealias 'DWORD', 'unsigned long'
  typealias 'HRESULT', 'long'
  
  # D3D10 doesn't have feature levels or separate context
  extern 'HRESULT D3D10CreateDeviceAndSwapChain(void*, UINT, void*, UINT, UINT, void*, void*, void*)'
end

# D3DCompiler
module D3DCompiler
  extend Fiddle::Importer
  begin
    dlload 'd3dcompiler_47.dll'
  rescue
    dlload 'd3dcompiler_43.dll'
  end
  
  D3DCOMPILE_ENABLE_STRICTNESS = 0x00000002
  
  typealias 'HRESULT', 'long'
  typealias 'SIZE_T', 'size_t'
  
  extern 'HRESULT D3DCompile(void*, SIZE_T, const char*, void*, void*, const char*, const char*, unsigned int, unsigned int, void*, void*)'
end

# COM Helper Module
module COM
  # Call COM method by vtable index
  def self.call(obj, index, ret_type, arg_types, *args)
    return nil if obj == 0 || obj.nil?
    
    # Get vtable pointer
    vtbl_ptr = Fiddle::Pointer.new(obj)[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    vtbl = Fiddle::Pointer.new(vtbl_ptr)
    
    # Get function pointer at index
    fn_ptr = vtbl[index * Fiddle::SIZEOF_VOIDP, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    
    # Create and call function
    fn = Fiddle::Function.new(fn_ptr, arg_types, ret_type)
    fn.call(*args)
  end
  
  # Release COM object
  def self.release(obj)
    return if obj == 0 || obj.nil?
    call(obj, 2, Fiddle::TYPE_ULONG, [Fiddle::TYPE_VOIDP], obj)
  end
  
  # ID3DBlob methods
  def self.blob_ptr(blob)
    call(blob, 3, Fiddle::TYPE_VOIDP, [Fiddle::TYPE_VOIDP], blob)
  end
  
  def self.blob_size(blob)
    call(blob, 4, Fiddle::TYPE_SIZE_T, [Fiddle::TYPE_VOIDP], blob)
  end
end

# GUID Helper
def create_guid(d1, d2, d3, d4_bytes)
  guid = Fiddle::Pointer.malloc(16)
  guid[0, 4] = [d1].pack('L')
  guid[4, 2] = [d2].pack('S')
  guid[6, 2] = [d3].pack('S')
  guid[8, 8] = d4_bytes.pack('C8')
  guid
end

# IID_ID3D10Texture2D (different from D3D11)
IID_ID3D10Texture2D = create_guid(0x9B7E4C04, 0x342C, 0x4106, [0xA1, 0x9F, 0x4F, 0x27, 0x04, 0xF6, 0x89, 0xF0])

# D3D10 Device vtable indices (device acts as both device and context)
module D3D10VTable
  # IDXGISwapChain
  SWAP_PRESENT = 8
  SWAP_GETBUFFER = 9
  
  # ID3D10Device
  DEVICE_PS_SET_SHADER = 5
  DEVICE_VS_SET_SHADER = 7
  DEVICE_DRAW = 9
  DEVICE_IA_SET_INPUT_LAYOUT = 11
  DEVICE_IA_SET_VERTEX_BUFFERS = 12
  DEVICE_IA_SET_PRIMITIVE_TOPOLOGY = 18
  DEVICE_OM_SET_RENDER_TARGETS = 24
  DEVICE_RS_SET_STATE = 29
  DEVICE_RS_SET_VIEWPORTS = 30
  DEVICE_CLEAR_RTV = 35
  DEVICE_CREATE_BUFFER = 71
  DEVICE_CREATE_RTV = 76
  DEVICE_CREATE_INPUT_LAYOUT = 78
  DEVICE_CREATE_VS = 79
  DEVICE_CREATE_PS = 82
  DEVICE_CREATE_RASTERIZER_STATE = 85
end

# HLSL Shader Source (use vs_4_0/ps_4_0 for D3D10)
HLSL_SRC = <<-HLSL
struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT output = (VS_OUTPUT)0;
    output.position = position;
    output.color = color;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    return input.color;
}
HLSL

# Compile HLSL shader
def compile_hlsl(entry, target)
  src = HLSL_SRC
  code_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  err_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  
  hr = D3DCompiler.D3DCompile(
    src, src.bytesize, "embedded.hlsl",
    nil, nil,
    entry, target,
    D3DCompiler::D3DCOMPILE_ENABLE_STRICTNESS, 0,
    code_ptr, err_ptr
  )
  
  if hr != 0
    err = err_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    if err != 0
      ptr = COM.blob_ptr(err)
      size = COM.blob_size(err)
      msg = Fiddle::Pointer.new(ptr).to_s(size)
      COM.release(err)
      raise "D3DCompile failed: #{msg}"
    end
    raise "D3DCompile failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}"
  end
  
  code_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
end

# Global D3D objects (D3D10 has no separate context)
$device = 0
$swap = 0
$rtv = 0
$vs = 0
$ps = 0
$layout = 0
$vb = 0
$rs = 0  # Rasterizer state
$hwnd = 0

# Initialize Direct3D 10
def init_d3d
  rc = User32::RECT.malloc
  User32.GetClientRect($hwnd, rc)
  width = rc.right - rc.left
  height = rc.bottom - rc.top
  
  puts "Client rect: #{width} x #{height}"
  
  # DXGI_SWAP_CHAIN_DESC (total 72 bytes)
  sd = Fiddle::Pointer.malloc(72)
  sd[0, 72] = "\0" * 72
  
  # BufferDesc
  sd[0, 4] = [width].pack('L')           # Width
  sd[4, 4] = [height].pack('L')          # Height
  sd[8, 4] = [60].pack('L')              # RefreshRate.Numerator
  sd[12, 4] = [1].pack('L')              # RefreshRate.Denominator
  sd[16, 4] = [D3D10::DXGI_FORMAT_R8G8B8A8_UNORM].pack('L')  # Format
  sd[20, 4] = [0].pack('L')              # ScanlineOrdering
  sd[24, 4] = [0].pack('L')              # Scaling
  # SampleDesc
  sd[28, 4] = [1].pack('L')              # Count
  sd[32, 4] = [0].pack('L')              # Quality
  # Rest
  sd[36, 4] = [D3D10::DXGI_USAGE_RENDER_TARGET_OUTPUT].pack('L')  # BufferUsage
  sd[40, 4] = [1].pack('L')              # BufferCount
  sd[48, 8] = [$hwnd].pack('Q')          # OutputWindow (Offset 48)
  sd[56, 4] = [1].pack('L')              # Windowed (Offset 56)
  sd[60, 4] = [0].pack('L')              # SwapEffect (Offset 60)
  sd[64, 4] = [0].pack('L')              # Flags (Offset 64)
  
  device_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  swap_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  
  driver_types = [D3D10::D3D_DRIVER_TYPE_HARDWARE, D3D10::D3D_DRIVER_TYPE_WARP, D3D10::D3D_DRIVER_TYPE_REFERENCE]
  hr = -1
  debug_enabled = false
  
  driver_types.each do |dt|
    # Try with debug layer first
    hr = D3D10.D3D10CreateDeviceAndSwapChain(
      nil, dt, nil,
      D3D10::D3D10_CREATE_DEVICE_DEBUG,
      D3D10::D3D10_SDK_VERSION,
      sd, swap_ptr, device_ptr
    )
    if hr == 0
      debug_enabled = true
      puts "Device created with DEBUG layer"
      break
    end
    
    # Try without debug
    hr = D3D10.D3D10CreateDeviceAndSwapChain(
      nil, dt, nil, 0,
      D3D10::D3D10_SDK_VERSION,
      sd, swap_ptr, device_ptr
    )
    break if hr == 0
  end
  
  raise "D3D10CreateDeviceAndSwapChain failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  
  $device = device_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  $swap = swap_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
  puts "D3D10 Device created: 0x#{$device.to_s(16)}"
  puts "SwapChain created: 0x#{$swap.to_s(16)}"
  
  # Get back buffer and create RTV
  backbuf_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  
  # IDXGISwapChain::GetBuffer (vtable index 9)
  hr = COM.call($swap, D3D10VTable::SWAP_GETBUFFER, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $swap, 0, IID_ID3D10Texture2D, backbuf_ptr)
  
  raise "SwapChain.GetBuffer failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  
  backbuf = backbuf_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  puts "Back buffer: 0x#{backbuf.to_s(16)}"
  
  # ID3D10Device::CreateRenderTargetView (vtable index 76)
  rtv_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, D3D10VTable::DEVICE_CREATE_RTV, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, backbuf, nil, rtv_ptr)
  
  COM.release(backbuf)
  raise "CreateRenderTargetView failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  
  $rtv = rtv_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  puts "Render target view: 0x#{$rtv.to_s(16)}"
  
  # OMSetRenderTargets (device vtable index 24) - D3D10 uses device directly
  rtv_arr = [$rtv].pack('Q')
  COM.call($device, D3D10VTable::DEVICE_OM_SET_RENDER_TARGETS, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, 1, rtv_arr, nil)
  
  # RSSetViewports (device vtable index 30)
  # D3D10_VIEWPORT: INT TopLeftX, INT TopLeftY, UINT Width, UINT Height, FLOAT MinDepth, FLOAT MaxDepth
  vp = [0, 0, width, height].pack('l2L2') + [0.0, 1.0].pack('f2')
  COM.call($device, D3D10VTable::DEVICE_RS_SET_VIEWPORTS, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP],
    $device, 1, vp)
  
  puts "Render target and viewport set"
  
  # Compile shaders (use vs_4_0/ps_4_0 for D3D10)
  puts "Compiling vertex shader..."
  vs_blob = compile_hlsl("VS", "vs_4_0")
  puts "Compiling pixel shader..."
  ps_blob = compile_hlsl("PS", "ps_4_0")
  
  # Create vertex shader (device vtable index 79) - D3D10 has no class linkage
  vs_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, D3D10VTable::DEVICE_CREATE_VS, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP],
    $device, COM.blob_ptr(vs_blob), COM.blob_size(vs_blob), vs_ptr)
  
  raise "CreateVertexShader failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  $vs = vs_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  puts "Vertex shader: 0x#{$vs.to_s(16)}"
  
  # Create input layout (device vtable index 78)
  # D3D10_INPUT_ELEMENT_DESC: SemanticName(8) + SemanticIndex(4) + Format(4) + InputSlot(4) + AlignedByteOffset(4) + InputSlotClass(4) + InstanceDataStepRate(4) = 32 bytes
  position_str = Fiddle::Pointer["POSITION\0"]
  color_str = Fiddle::Pointer["COLOR\0"]
  
  layout_desc = Fiddle::Pointer.malloc(64)  # 2 elements * 32 bytes
  # Element 0: POSITION
  layout_desc[0, 8] = [position_str.to_i].pack('Q')
  layout_desc[8, 4] = [0].pack('L')  # SemanticIndex
  layout_desc[12, 4] = [D3D10::DXGI_FORMAT_R32G32B32_FLOAT].pack('L')  # Format
  layout_desc[16, 4] = [0].pack('L')  # InputSlot
  layout_desc[20, 4] = [0].pack('L')  # AlignedByteOffset
  layout_desc[24, 4] = [D3D10::D3D10_INPUT_PER_VERTEX_DATA].pack('L')
  layout_desc[28, 4] = [0].pack('L')  # InstanceDataStepRate
  # Element 1: COLOR
  layout_desc[32, 8] = [color_str.to_i].pack('Q')
  layout_desc[40, 4] = [0].pack('L')
  layout_desc[44, 4] = [D3D10::DXGI_FORMAT_R32G32B32A32_FLOAT].pack('L')
  layout_desc[48, 4] = [0].pack('L')
  layout_desc[52, 4] = [12].pack('L')  # Offset after float3
  layout_desc[56, 4] = [D3D10::D3D10_INPUT_PER_VERTEX_DATA].pack('L')
  layout_desc[60, 4] = [0].pack('L')
  
  layout_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, D3D10VTable::DEVICE_CREATE_INPUT_LAYOUT, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP],
    $device, layout_desc, 2, COM.blob_ptr(vs_blob), COM.blob_size(vs_blob), layout_ptr)
  
  raise "CreateInputLayout failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  $layout = layout_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  puts "Input layout: 0x#{$layout.to_s(16)}"
  
  # IASetInputLayout (device vtable index 11)
  COM.call($device, D3D10VTable::DEVICE_IA_SET_INPUT_LAYOUT, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, $layout)
  
  # Create pixel shader (device vtable index 82) - D3D10 has no class linkage
  ps_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, D3D10VTable::DEVICE_CREATE_PS, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP],
    $device, COM.blob_ptr(ps_blob), COM.blob_size(ps_blob), ps_ptr)
  
  raise "CreatePixelShader failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  $ps = ps_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  puts "Pixel shader: 0x#{$ps.to_s(16)}"
  
  COM.release(vs_blob)
  COM.release(ps_blob)
  
  puts "Shaders created"
  
  # Create vertex buffer
  # Vertex: float3 position + float4 color = 28 bytes
  vertices = [
     0.0,  0.5, 0.5,  1.0, 0.0, 0.0, 1.0,  # Red
     0.5, -0.5, 0.5,  0.0, 1.0, 0.0, 1.0,  # Green
    -0.5, -0.5, 0.5,  0.0, 0.0, 1.0, 1.0   # Blue
  ].pack('f*')
  
  # D3D10_BUFFER_DESC: 24 bytes
  bd = Fiddle::Pointer.malloc(24)
  bd[0, 4] = [vertices.bytesize].pack('L')  # ByteWidth
  bd[4, 4] = [D3D10::D3D10_USAGE_DEFAULT].pack('L')
  bd[8, 4] = [D3D10::D3D10_BIND_VERTEX_BUFFER].pack('L')
  bd[12, 4] = [0].pack('L')  # CPUAccessFlags
  bd[16, 4] = [0].pack('L')  # MiscFlags
  bd[20, 4] = [0].pack('L')  # StructureByteStride
  
  # D3D10_SUBRESOURCE_DATA: 24 bytes (on 64-bit)
  init_data = Fiddle::Pointer.malloc(24)
  init_data[0, 8] = [Fiddle::Pointer[vertices].to_i].pack('Q')
  init_data[8, 4] = [0].pack('L')
  init_data[12, 4] = [0].pack('L')
  
  # ID3D10Device::CreateBuffer (vtable index 71)
  vb_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, D3D10VTable::DEVICE_CREATE_BUFFER, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, bd, init_data, vb_ptr)
  
  raise "CreateBuffer failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  $vb = vb_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  puts "Vertex buffer: 0x#{$vb.to_s(16)}"
  
  # IASetVertexBuffers (device vtable index 12)
  stride = [28].pack('L')  # sizeof(Vertex)
  offset = [0].pack('L')
  vb_arr = [$vb].pack('Q')
  COM.call($device, D3D10VTable::DEVICE_IA_SET_VERTEX_BUFFERS, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, 0, 1, vb_arr, stride, offset)
  
  # IASetPrimitiveTopology (device vtable index 18)
  COM.call($device, D3D10VTable::DEVICE_IA_SET_PRIMITIVE_TOPOLOGY, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
    $device, D3D10::D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
  
  puts "Vertex buffer created"
  
  # Create rasterizer state (disable backface culling)
  # D3D10_RASTERIZER_DESC: 40 bytes
  # FillMode(4), CullMode(4), FrontCounterClockwise(4), DepthBias(4), DepthBiasClamp(4),
  # SlopeScaledDepthBias(4), DepthClipEnable(4), ScissorEnable(4), MultisampleEnable(4), AntialiasedLineEnable(4)
  rs_desc = Fiddle::Pointer.malloc(40)
  rs_desc[0, 4] = [D3D10::D3D10_FILL_SOLID].pack('L')  # FillMode = SOLID (3)
  rs_desc[4, 4] = [D3D10::D3D10_CULL_NONE].pack('L')   # CullMode = NONE (1)
  rs_desc[8, 4] = [0].pack('L')                         # FrontCounterClockwise = FALSE
  rs_desc[12, 4] = [0].pack('l')                        # DepthBias = 0
  rs_desc[16, 4] = [0.0].pack('f')                      # DepthBiasClamp = 0.0
  rs_desc[20, 4] = [0.0].pack('f')                      # SlopeScaledDepthBias = 0.0
  rs_desc[24, 4] = [1].pack('L')                        # DepthClipEnable = TRUE (required for D3D10)
  rs_desc[28, 4] = [0].pack('L')                        # ScissorEnable = FALSE
  rs_desc[32, 4] = [0].pack('L')                        # MultisampleEnable = FALSE
  rs_desc[36, 4] = [0].pack('L')                        # AntialiasedLineEnable = FALSE
  
  rs_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, D3D10VTable::DEVICE_CREATE_RASTERIZER_STATE, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, rs_desc, rs_ptr)
  
  if hr == 0
    $rs = rs_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    puts "Rasterizer state: 0x#{$rs.to_s(16)}"
    
    # RSSetState (device vtable index 29)
    COM.call($device, D3D10VTable::DEVICE_RS_SET_STATE, Fiddle::TYPE_VOID,
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
      $device, $rs)
    puts "Rasterizer state set (no culling, solid fill)"
  else
    puts "Warning: CreateRasterizerState failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}"
  end
  
  puts "D3D10 initialization complete"
end

# Cleanup D3D resources
def cleanup_d3d
  COM.release($rs) if $rs != 0
  COM.release($vb)
  COM.release($layout)
  COM.release($vs)
  COM.release($ps)
  COM.release($rtv)
  COM.release($swap)
  COM.release($device)
end

# Render frame
def render
  # ClearRenderTargetView (device vtable index 35)
  color = [1.0, 1.0, 1.0, 1.0].pack('f4')  # White background
  COM.call($device, D3D10VTable::DEVICE_CLEAR_RTV, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, $rtv, color)
  
  # VSSetShader (device vtable index 7) - D3D10 takes only shader pointer
  COM.call($device, D3D10VTable::DEVICE_VS_SET_SHADER, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, $vs)
  
  # PSSetShader (device vtable index 5) - D3D10 takes only shader pointer
  COM.call($device, D3D10VTable::DEVICE_PS_SET_SHADER, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, $ps)
  
  # Draw (device vtable index 9)
  COM.call($device, D3D10VTable::DEVICE_DRAW, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT],
    $device, 3, 0)
  
  # Present (swapchain vtable index 8)
  COM.call($swap, D3D10VTable::SWAP_PRESENT, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT],
    $swap, 0, 0)
end

# Window Procedure
WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_UINT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  case msg
  when User32::WM_NCCREATE
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  when User32::WM_DESTROY
    User32.PostQuitMessage(0)
    0
  else
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  end
end

# Main Program
puts "=== DirectX 10 Triangle (Ruby) ==="

Ole32.CoInitialize(nil)

hInstance = Kernel32.GetModuleHandleA(nil)
class_name = "RubyDX10"

wc = User32::WNDCLASSEX.malloc
wc.cbSize = User32::WNDCLASSEX.size
wc.style = User32::CS_HREDRAW | User32::CS_VREDRAW
wc.lpfnWndProc = WndProc.to_i
wc.cbClsExtra = 0
wc.cbWndExtra = 0
wc.hInstance = hInstance
wc.hIcon = 0
wc.hCursor = User32.LoadCursorA(0, User32::IDC_ARROW)
wc.hbrBackground = 0
wc.lpszMenuName = 0
wc.lpszClassName = Fiddle::Pointer[class_name].to_i
wc.hIconSm = 0

atom = User32.RegisterClassExA(wc)
raise "RegisterClassExA failed" if atom == 0

$hwnd = User32.CreateWindowExA(
  0, class_name, "DirectX 10 Triangle (Ruby)",
  User32::WS_OVERLAPPEDWINDOW,
  User32::CW_USEDEFAULT, User32::CW_USEDEFAULT,
  640, 480,
  0, 0, hInstance, nil
)
raise "CreateWindowExA failed" if $hwnd == 0

User32.ShowWindow($hwnd, User32::SW_SHOW)

init_d3d

puts "Entering render loop..."
msg = User32::MSG.malloc
running = true
frame_count = 0

while running
  if User32.PeekMessageA(msg, 0, 0, 0, User32::PM_REMOVE) != 0
    if msg.message == User32::WM_QUIT
      running = false
    else
      User32.TranslateMessage(msg)
      User32.DispatchMessageA(msg)
    end
  else
    render
    frame_count += 1
    Kernel32.Sleep(1)
  end
end

puts "Total frames rendered: #{frame_count}"
puts "Cleaning up..."
cleanup_d3d
Ole32.CoUninitialize

puts "=== Program End ==="
