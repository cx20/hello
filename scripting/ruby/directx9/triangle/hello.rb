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

  extern 'USHORT RegisterClassExA(void*)'
  extern 'UINTPTR CreateWindowExA(DWORD, const char*, const char*, DWORD, int, int, int, int, UINTPTR, UINTPTR, UINTPTR, void*)'
  extern 'int ShowWindow(UINTPTR, int)'
  extern 'int UpdateWindow(UINTPTR)'
  extern 'BOOL PeekMessageA(void*, UINTPTR, UINT, UINT, UINT)'
  extern 'int TranslateMessage(void*)'
  extern 'UINTPTR DispatchMessageA(void*)'
  extern 'void PostQuitMessage(int)'
  extern 'UINTPTR DefWindowProcA(UINTPTR, UINT, UINTPTR, UINTPTR)'
  extern 'UINTPTR LoadCursorA(UINTPTR, UINTPTR)'
end

# Kernel32.dll
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'

  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'void Sleep(unsigned long)'
end

# D3D9.dll
module D3D9
  extend Fiddle::Importer
  dlload 'd3d9.dll'

  typealias 'UINT', 'unsigned int'
  typealias 'DWORD', 'unsigned long'
  typealias 'HRESULT', 'long'

  extern 'void* Direct3DCreate9(UINT)'
end

def pack_ptr(value)
  [value].pack(Fiddle::SIZEOF_VOIDP == 8 ? 'Q' : 'L')
end

def unpack_ptr(bytes)
  bytes.unpack1(Fiddle::SIZEOF_VOIDP == 8 ? 'Q' : 'L')
end

def d3dcolor_xrgb(r, g, b)
  0xFF000000 | (r << 16) | (g << 8) | b
end

# COM Helper Module
module COM
  def self.call(obj, index, ret_type, arg_types, *args)
    return nil if obj == 0 || obj.nil?

    vtbl_addr = unpack_ptr(Fiddle::Pointer.new(obj)[0, Fiddle::SIZEOF_VOIDP])
    vtbl = Fiddle::Pointer.new(vtbl_addr)
    fn_addr = unpack_ptr(vtbl[index * Fiddle::SIZEOF_VOIDP, Fiddle::SIZEOF_VOIDP])
    abi = Fiddle::SIZEOF_VOIDP == 8 ? Fiddle::Function::DEFAULT : Fiddle::Function::STDCALL
    fn = Fiddle::Function.new(fn_addr, arg_types, ret_type, abi)
    fn.call(*args)
  end

  def self.release(obj)
    return if obj == 0 || obj.nil?
    call(obj, 2, Fiddle::TYPE_ULONG, [Fiddle::TYPE_VOIDP], obj)
  end
end

# DirectX 9 constants
D3D_SDK_VERSION = 32
D3DADAPTER_DEFAULT = 0
D3DDEVTYPE_HAL = 1
D3DCREATE_SOFTWARE_VERTEXPROCESSING = 0x00000020
D3DFMT_UNKNOWN = 0
D3DSWAPEFFECT_DISCARD = 1
D3DPOOL_DEFAULT = 0
D3DCLEAR_TARGET = 0x00000001
D3DPT_TRIANGLELIST = 4

D3DFVF_XYZRHW = 0x004
D3DFVF_DIFFUSE = 0x040
D3DFVF_VERTEX = D3DFVF_XYZRHW | D3DFVF_DIFFUSE

# COM vtable indices
IDirect3D9_CreateDevice = 16
IDirect3DDevice9_Present = 17
IDirect3DDevice9_CreateVertexBuffer = 26
IDirect3DDevice9_BeginScene = 41
IDirect3DDevice9_EndScene = 42
IDirect3DDevice9_Clear = 43
IDirect3DDevice9_DrawPrimitive = 81
IDirect3DDevice9_SetFVF = 89
IDirect3DDevice9_SetStreamSource = 100
IDirect3DVertexBuffer9_Lock = 11
IDirect3DVertexBuffer9_Unlock = 12

$hwnd = 0
$d3d = 0
$device = 0
$vb = 0

def build_d3dpp(hwnd)
  if Fiddle::SIZEOF_VOIDP == 8
    data = [
      0, 0, D3DFMT_UNKNOWN, 1,
      0, 0, D3DSWAPEFFECT_DISCARD
    ].pack('L7')
    data << [0].pack('L')
    data << pack_ptr(hwnd)
    data << [1, 0, 0, 0, 0, 0].pack('L6')
  else
    data = [
      0, 0, D3DFMT_UNKNOWN, 1,
      0, 0, D3DSWAPEFFECT_DISCARD,
      hwnd, 1, 0, 0, 0, 0, 0
    ].pack('L14')
  end
  data
end

def init_d3d
  $d3d = D3D9.Direct3DCreate9(D3D_SDK_VERSION)
  raise 'Direct3DCreate9 failed' if $d3d == 0

  d3dpp_data = build_d3dpp($hwnd)
  d3dpp = Fiddle::Pointer.malloc(d3dpp_data.bytesize)
  d3dpp[0, d3dpp_data.bytesize] = d3dpp_data

  device_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(
    $d3d, IDirect3D9_CreateDevice, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP,
     Fiddle::TYPE_ULONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $d3d, D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, $hwnd,
    D3DCREATE_SOFTWARE_VERTEXPROCESSING, d3dpp, device_ptr
  )
  raise format('CreateDevice failed: HRESULT=0x%08X', hr & 0xFFFFFFFF) if hr != 0
  $device = unpack_ptr(device_ptr[0, Fiddle::SIZEOF_VOIDP])

  init_vb
end

def init_vb
  vertices = [
    [320.0, 100.0, 0.0, 1.0, d3dcolor_xrgb(255, 0, 0)],
    [520.0, 380.0, 0.0, 1.0, d3dcolor_xrgb(0, 255, 0)],
    [120.0, 380.0, 0.0, 1.0, d3dcolor_xrgb(0, 0, 255)]
  ]

  vertex_data = vertices.map do |v|
    [v[0], v[1], v[2], v[3]].pack('f4') + [v[4]].pack('L')
  end.join

  vb_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(
    $device, IDirect3DDevice9_CreateVertexBuffer, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_ULONG, Fiddle::TYPE_ULONG,
     Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, vertex_data.bytesize, 0, D3DFVF_VERTEX,
    D3DPOOL_DEFAULT, vb_ptr, 0
  )
  raise format('CreateVertexBuffer failed: HRESULT=0x%08X', hr & 0xFFFFFFFF) if hr != 0
  $vb = unpack_ptr(vb_ptr[0, Fiddle::SIZEOF_VOIDP])

  data_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(
    $vb, IDirect3DVertexBuffer9_Lock, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG],
    $vb, 0, vertex_data.bytesize, data_ptr, 0
  )
  raise format('Lock failed: HRESULT=0x%08X', hr & 0xFFFFFFFF) if hr != 0

  dest = unpack_ptr(data_ptr[0, Fiddle::SIZEOF_VOIDP])
  Fiddle::Pointer.new(dest)[0, vertex_data.bytesize] = vertex_data

  COM.call(
    $vb, IDirect3DVertexBuffer9_Unlock, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP], $vb
  )
end

def cleanup
  COM.release($vb)
  COM.release($device)
  COM.release($d3d)
end

def render
  return if $device == 0

  COM.call(
    $device, IDirect3DDevice9_Clear, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG,
     Fiddle::TYPE_ULONG, Fiddle::TYPE_FLOAT, Fiddle::TYPE_ULONG],
    $device, 0, 0, D3DCLEAR_TARGET, d3dcolor_xrgb(255, 255, 255), 1.0, 0
  )

  hr = COM.call(
    $device, IDirect3DDevice9_BeginScene, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP], $device
  )

  if hr == 0
    COM.call(
      $device, IDirect3DDevice9_SetStreamSource, Fiddle::TYPE_LONG,
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT],
      $device, 0, $vb, 0, 20
    )

    COM.call(
      $device, IDirect3DDevice9_SetFVF, Fiddle::TYPE_LONG,
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG],
      $device, D3DFVF_VERTEX
    )

    COM.call(
      $device, IDirect3DDevice9_DrawPrimitive, Fiddle::TYPE_LONG,
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT],
      $device, D3DPT_TRIANGLELIST, 0, 1
    )

    COM.call(
      $device, IDirect3DDevice9_EndScene, Fiddle::TYPE_LONG,
      [Fiddle::TYPE_VOIDP], $device
    )
  end

  COM.call(
    $device, IDirect3DDevice9_Present, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $device, 0, 0, 0, 0
  )
end

WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_UINT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  if msg == User32::WM_DESTROY
    User32.PostQuitMessage(0)
    0
  else
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  end
end

puts '=== DirectX 9 Triangle (Ruby) ==='

hInstance = Kernel32.GetModuleHandleA(nil)
class_name = 'RubyDX9'

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
raise 'RegisterClassExA failed' if atom == 0

$hwnd = User32.CreateWindowExA(
  0, class_name, 'DirectX 9 Triangle (Ruby)',
  User32::WS_OVERLAPPEDWINDOW,
  User32::CW_USEDEFAULT, User32::CW_USEDEFAULT,
  640, 480,
  0, 0, hInstance, nil
)
raise 'CreateWindowExA failed' if $hwnd == 0

User32.ShowWindow($hwnd, User32::SW_SHOW)
User32.UpdateWindow($hwnd)

init_d3d

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

cleanup
puts '=== Program End ==='
