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

# D3D11.dll
module D3D11
  extend Fiddle::Importer
  dlload 'd3d11.dll'
  
  D3D11_SDK_VERSION = 7
  D3D_DRIVER_TYPE_HARDWARE = 1
  D3D_DRIVER_TYPE_WARP = 5
  D3D_DRIVER_TYPE_REFERENCE = 2
  D3D_FEATURE_LEVEL_11_0 = 0xB000
  
  DXGI_FORMAT_R8G8B8A8_UNORM = 28
  DXGI_FORMAT_R32G32B32_FLOAT = 6
  DXGI_FORMAT_R32G32B32A32_FLOAT = 2
  DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020
  
  D3D11_USAGE_DEFAULT = 0
  D3D11_BIND_VERTEX_BUFFER = 0x00000001
  D3D11_INPUT_PER_VERTEX_DATA = 0
  D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4
  
  typealias 'UINT', 'unsigned int'
  typealias 'DWORD', 'unsigned long'
  typealias 'HRESULT', 'long'
  
  extern 'HRESULT D3D11CreateDeviceAndSwapChain(void*, UINT, void*, UINT, void*, UINT, UINT, void*, void*, void*, void*, void*)'
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

# IID_ID3D11Texture2D
IID_ID3D11Texture2D = create_guid(0x6f15aaf2, 0xd208, 0x4e89, [0x9a, 0xb4, 0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c])

# HLSL Shader Source
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
    err = code_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
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

# Global D3D objects
$device = 0
$context = 0
$swap = 0
$rtv = 0
$vs = 0
$ps = 0
$layout = 0
$vb = 0
$hwnd = 0

# Initialize Direct3D 11
def init_d3d
  rc = User32::RECT.malloc
  User32.GetClientRect($hwnd, rc)
  width = rc.right - rc.left
  height = rc.bottom - rc.top
  
  # DXGI_SWAP_CHAIN_DESC (total 72 bytes)
  sd = Fiddle::Pointer.malloc(72)
  sd[0, 72] = "\0" * 72
  
  # BufferDesc
  sd[0, 4] = [width].pack('L')           # Width
  sd[4, 4] = [height].pack('L')          # Height
  sd[8, 4] = [60].pack('L')              # RefreshRate.Numerator
  sd[12, 4] = [1].pack('L')              # RefreshRate.Denominator
  sd[16, 4] = [D3D11::DXGI_FORMAT_R8G8B8A8_UNORM].pack('L')  # Format
  sd[20, 4] = [0].pack('L')              # ScanlineOrdering
  sd[24, 4] = [0].pack('L')              # Scaling
  # SampleDesc
  sd[28, 4] = [1].pack('L')              # Count
  sd[32, 4] = [0].pack('L')              # Quality
  # Rest
  sd[36, 4] = [D3D11::DXGI_USAGE_RENDER_TARGET_OUTPUT].pack('L')  # BufferUsage
  sd[40, 4] = [1].pack('L')              # BufferCount
  sd[48, 8] = [$hwnd].pack('Q')          # OutputWindow (Offset 48)
  sd[56, 4] = [1].pack('L')              # Windowed (Offset 56)
  sd[60, 4] = [0].pack('L')              # SwapEffect (Offset 60)
  sd[64, 4] = [0].pack('L')              # Flags (Offset 64)
    
  feature_levels = [D3D11::D3D_FEATURE_LEVEL_11_0].pack('L')
  created_level = Fiddle::Pointer.malloc(4)
  
  device_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  context_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  swap_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  
  driver_types = [D3D11::D3D_DRIVER_TYPE_HARDWARE, D3D11::D3D_DRIVER_TYPE_WARP, D3D11::D3D_DRIVER_TYPE_REFERENCE]
  hr = -1
  
  driver_types.each do |dt|
    hr = D3D11.D3D11CreateDeviceAndSwapChain(
      nil, dt, nil, 0,
      feature_levels, 1,
      D3D11::D3D11_SDK_VERSION,
      sd, swap_ptr, device_ptr, created_level, context_ptr
    )
    break if hr == 0
  end
  
  raise "D3D11CreateDeviceAndSwapChain failed: HRESULT=0x#{(hr & 0xFFFFFFFF).to_s(16)}" if hr != 0
  
  $device = device_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  $context = context_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  $swap = swap_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
  puts "D3D11 Device created"
  
  # Get back buffer and create RTV
  backbuf_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  
  # IDXGISwapChain::GetBuffer (vtable index 9)
  hr = COM.call($swap, 9, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $swap, 0, IID_ID3D11Texture2D, backbuf_ptr)
  
  raise "SwapChain.GetBuffer failed" if hr != 0
  
  backbuf = backbuf_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
  # ID3D11Device::CreateRenderTargetView (vtable index 9)
  rtv_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 9, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, backbuf, nil, rtv_ptr)
  
  COM.release(backbuf)
  raise "CreateRenderTargetView failed" if hr != 0
  
  $rtv = rtv_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
  # OMSetRenderTargets (context vtable index 33)
  rtv_arr = [$rtv].pack('Q')
  COM.call($context, 33, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $context, 1, rtv_arr, nil)
  
  # RSSetViewports (context vtable index 44)
  # D3D11_VIEWPORT: 6 floats
  vp = [0.0, 0.0, width.to_f, height.to_f, 0.0, 1.0].pack('f6')
  COM.call($context, 44, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP],
    $context, 1, vp)
  
  puts "Render target and viewport set"
  
  # Compile shaders
  puts "Compiling vertex shader..."
  vs_blob = compile_hlsl("VS", "vs_4_0")
  puts "Compiling pixel shader..."
  ps_blob = compile_hlsl("PS", "ps_4_0")
  
  # Create vertex shader (device vtable index 12)
  vs_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 12, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, COM.blob_ptr(vs_blob), COM.blob_size(vs_blob), nil, vs_ptr)
  
  raise "CreateVertexShader failed" if hr != 0
  $vs = vs_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
  # Create input layout (device vtable index 11)
  # D3D11_INPUT_ELEMENT_DESC: SemanticName(8) + SemanticIndex(4) + Format(4) + InputSlot(4) + AlignedByteOffset(4) + InputSlotClass(4) + InstanceDataStepRate(4) = 32 bytes
  position_str = Fiddle::Pointer["POSITION\0"]
  color_str = Fiddle::Pointer["COLOR\0"]
  
  layout_desc = Fiddle::Pointer.malloc(64)  # 2 elements * 32 bytes
  # Element 0: POSITION
  layout_desc[0, 8] = [position_str.to_i].pack('Q')
  layout_desc[8, 4] = [0].pack('L')  # SemanticIndex
  layout_desc[12, 4] = [D3D11::DXGI_FORMAT_R32G32B32_FLOAT].pack('L')  # Format
  layout_desc[16, 4] = [0].pack('L')  # InputSlot
  layout_desc[20, 4] = [0].pack('L')  # AlignedByteOffset
  layout_desc[24, 4] = [D3D11::D3D11_INPUT_PER_VERTEX_DATA].pack('L')
  layout_desc[28, 4] = [0].pack('L')  # InstanceDataStepRate
  # Element 1: COLOR
  layout_desc[32, 8] = [color_str.to_i].pack('Q')
  layout_desc[40, 4] = [0].pack('L')
  layout_desc[44, 4] = [D3D11::DXGI_FORMAT_R32G32B32A32_FLOAT].pack('L')
  layout_desc[48, 4] = [0].pack('L')
  layout_desc[52, 4] = [12].pack('L')  # Offset after float3
  layout_desc[56, 4] = [D3D11::D3D11_INPUT_PER_VERTEX_DATA].pack('L')
  layout_desc[60, 4] = [0].pack('L')
  
  layout_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 11, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP],
    $device, layout_desc, 2, COM.blob_ptr(vs_blob), COM.blob_size(vs_blob), layout_ptr)
  
  raise "CreateInputLayout failed" if hr != 0
  $layout = layout_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
  # IASetInputLayout (context vtable index 17)
  COM.call($context, 17, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $context, $layout)
  
  # Create pixel shader (device vtable index 15)
  ps_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 15, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, COM.blob_ptr(ps_blob), COM.blob_size(ps_blob), nil, ps_ptr)
  
  raise "CreatePixelShader failed" if hr != 0
  $ps = ps_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
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
  
  # D3D11_BUFFER_DESC: 24 bytes
  bd = Fiddle::Pointer.malloc(24)
  bd[0, 4] = [vertices.bytesize].pack('L')  # ByteWidth
  bd[4, 4] = [D3D11::D3D11_USAGE_DEFAULT].pack('L')
  bd[8, 4] = [D3D11::D3D11_BIND_VERTEX_BUFFER].pack('L')
  bd[12, 4] = [0].pack('L')  # CPUAccessFlags
  bd[16, 4] = [0].pack('L')  # MiscFlags
  bd[20, 4] = [0].pack('L')  # StructureByteStride
  
  # D3D11_SUBRESOURCE_DATA: 24 bytes (on 64-bit)
  init_data = Fiddle::Pointer.malloc(24)
  init_data[0, 8] = [Fiddle::Pointer[vertices].to_i].pack('Q')
  init_data[8, 4] = [0].pack('L')
  init_data[12, 4] = [0].pack('L')
  
  # ID3D11Device::CreateBuffer (vtable index 3)
  vb_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 3, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, bd, init_data, vb_ptr)
  
  raise "CreateBuffer failed" if hr != 0
  $vb = vb_ptr[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  
  # IASetVertexBuffers (context vtable index 18)
  stride = [28].pack('L')  # sizeof(Vertex)
  offset = [0].pack('L')
  vb_arr = [$vb].pack('Q')
  COM.call($context, 18, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $context, 0, 1, vb_arr, stride, offset)
  
  # IASetPrimitiveTopology (context vtable index 24)
  COM.call($context, 24, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
    $context, D3D11::D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST)
  
  puts "Vertex buffer created"
  puts "D3D11 initialization complete"
end

# Cleanup D3D resources
def cleanup_d3d
  COM.release($vb)
  COM.release($layout)
  COM.release($vs)
  COM.release($ps)
  COM.release($rtv)
  COM.release($swap)
  COM.release($context)
  COM.release($device)
end

# Render frame
def render
  # ClearRenderTargetView (context vtable index 50)
  color = [1.0, 1.0, 1.0, 1.0].pack('f4')  # White background
  COM.call($context, 50, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $context, $rtv, color)
  
  # VSSetShader (context vtable index 11)
  COM.call($context, 11, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
    $context, $vs, nil, 0)
  
  # PSSetShader (context vtable index 9)
  COM.call($context, 9, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
    $context, $ps, nil, 0)
  
  # Draw (context vtable index 13)
  COM.call($context, 13, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT],
    $context, 3, 0)
  
  # Present (swapchain vtable index 8)
  COM.call($swap, 8, Fiddle::TYPE_LONG,
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
puts "=== DirectX 11 Triangle (Ruby) ==="

Ole32.CoInitialize(nil)

hInstance = Kernel32.GetModuleHandleA(nil)
class_name = "RubyDX11"

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
  0, class_name, "DirectX 11 Triangle (Ruby)",
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
    Kernel32.Sleep(1)
  end
end

puts "Cleaning up..."
cleanup_d3d
Ole32.CoUninitialize

puts "=== Program End ==="
