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
  WM_PAINT = 0x000F
  WM_SIZE = 0x0005
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

  RECT = struct([
    'long left', 'long top', 'long right', 'long bottom'
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
  extern 'BOOL GetClientRect(UINTPTR, void*)'
  extern 'BOOL ValidateRect(UINTPTR, void*)'
  extern 'BOOL InvalidateRect(UINTPTR, void*, BOOL)'
end

# Kernel32.dll
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'

  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'uintptr_t LoadLibraryA(const char*)'
  extern 'uintptr_t GetProcAddress(uintptr_t, const char*)'
  extern 'int FreeLibrary(uintptr_t)'
  extern 'void Sleep(unsigned long)'
end

def pack_ptr(value)
  [value].pack(Fiddle::SIZEOF_VOIDP == 8 ? 'Q' : 'L')
end

def unpack_ptr(bytes)
  bytes.unpack1(Fiddle::SIZEOF_VOIDP == 8 ? 'Q' : 'L')
end

def point2f_value(x, y)
  [x, y].pack('f2').unpack1('Q')
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

# Direct2D constants
+D2D1_FACTORY_TYPE_SINGLE_THREADED = 0
+D2D1_RENDER_TARGET_TYPE_DEFAULT = 0
+D2D1_ALPHA_MODE_UNKNOWN = 0
+D2D1_RENDER_TARGET_USAGE_NONE = 0
+D2D1_FEATURE_LEVEL_DEFAULT = 0
+D2D1_PRESENT_OPTIONS_NONE = 0

# COM vtable indices
ID2D1Factory_CreateHwndRenderTarget = 14
ID2D1RenderTarget_CreateSolidColorBrush = 8
ID2D1RenderTarget_DrawLine = 15
ID2D1RenderTarget_Clear = 47
ID2D1RenderTarget_BeginDraw = 48
ID2D1RenderTarget_EndDraw = 49
ID2D1HwndRenderTarget_Resize = 58

# IID_ID2D1Factory
IID_ID2D1Factory = [
  0x47, 0x22, 0x15, 0x06,
  0x50, 0x6f,
  0x5a, 0x46,
  0x92, 0x45, 0x11, 0x8b, 0xfd, 0x3b, 0x60, 0x07
].pack('C16')

$hwnd = 0
$h_d2d1 = 0
$factory = 0
$render_target = 0
$brush = 0

def build_rt_props
  pixel_format = [0, D2D1_ALPHA_MODE_UNKNOWN].pack('L2')
  [D2D1_RENDER_TARGET_TYPE_DEFAULT].pack('L') +
    pixel_format +
    [0.0, 0.0].pack('f2') +
    [D2D1_RENDER_TARGET_USAGE_NONE, D2D1_FEATURE_LEVEL_DEFAULT].pack('L2')
end

def build_hwnd_props(hwnd, width, height)
  if Fiddle::SIZEOF_VOIDP == 8
    pack_ptr(hwnd) +
      [width, height].pack('L2') +
      [D2D1_PRESENT_OPTIONS_NONE, 0].pack('L2')
  else
    [hwnd, width, height, D2D1_PRESENT_OPTIONS_NONE].pack('L4')
  end
end

def d2d1_color_f(r, g, b, a)
  [r, g, b, a].pack('f4')
end

def init_d2d
  $h_d2d1 = Kernel32.LoadLibraryA('d2d1.dll')
  raise 'LoadLibraryA(d2d1.dll) failed' if $h_d2d1 == 0

  proc_addr = Kernel32.GetProcAddress($h_d2d1, 'D2D1CreateFactory')
  raise 'GetProcAddress(D2D1CreateFactory) failed' if proc_addr == 0

  create_factory = Fiddle::Function.new(
    proc_addr,
    [Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    Fiddle::TYPE_LONG,
    Fiddle::SIZEOF_VOIDP == 8 ? Fiddle::Function::DEFAULT : Fiddle::Function::STDCALL
  )

  iid_ptr = Fiddle::Pointer.malloc(16)
  iid_ptr[0, 16] = IID_ID2D1Factory
  factory_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)

  hr = create_factory.call(
    D2D1_FACTORY_TYPE_SINGLE_THREADED,
    iid_ptr,
    0,
    factory_ptr
  )
  raise format('D2D1CreateFactory failed: HRESULT=0x%08X', hr & 0xFFFFFFFF) if hr != 0
  $factory = unpack_ptr(factory_ptr[0, Fiddle::SIZEOF_VOIDP])

  rc = User32::RECT.malloc
  User32.GetClientRect($hwnd, rc)
  width = rc.right - rc.left
  height = rc.bottom - rc.top
  width = 640 if width <= 0
  height = 480 if height <= 0

  rt_props_data = build_rt_props
  rt_props = Fiddle::Pointer.malloc(rt_props_data.bytesize)
  rt_props[0, rt_props_data.bytesize] = rt_props_data

  hwnd_props_data = build_hwnd_props($hwnd, width, height)
  hwnd_props = Fiddle::Pointer.malloc(hwnd_props_data.bytesize)
  hwnd_props[0, hwnd_props_data.bytesize] = hwnd_props_data

  rt_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(
    $factory, ID2D1Factory_CreateHwndRenderTarget, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $factory, rt_props, hwnd_props, rt_ptr
  )
  raise format('CreateHwndRenderTarget failed: HRESULT=0x%08X', hr & 0xFFFFFFFF) if hr != 0
  $render_target = unpack_ptr(rt_ptr[0, Fiddle::SIZEOF_VOIDP])

  color = d2d1_color_f(0.0, 0.0, 1.0, 1.0)
  color_ptr = Fiddle::Pointer.malloc(color.bytesize)
  color_ptr[0, color.bytesize] = color

  brush_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(
    $render_target, ID2D1RenderTarget_CreateSolidColorBrush, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $render_target, color_ptr, 0, brush_ptr
  )
  raise format('CreateSolidColorBrush failed: HRESULT=0x%08X', hr & 0xFFFFFFFF) if hr != 0
  $brush = unpack_ptr(brush_ptr[0, Fiddle::SIZEOF_VOIDP])
end

def cleanup
  COM.release($brush)
  COM.release($render_target)
  COM.release($factory)
  Kernel32.FreeLibrary($h_d2d1) if $h_d2d1 != 0
end

def resize_render_target(width, height)
  return if $render_target == 0
  width = 1 if width <= 0
  height = 1 if height <= 0

  size_data = [width, height].pack('L2')
  size_ptr = Fiddle::Pointer.malloc(size_data.bytesize)
  size_ptr[0, size_data.bytesize] = size_data

  COM.call(
    $render_target, ID2D1HwndRenderTarget_Resize, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $render_target, size_ptr
  )
end

def draw
  return if $render_target == 0

  COM.call(
    $render_target, ID2D1RenderTarget_BeginDraw, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP], $render_target
  )

  white = d2d1_color_f(1.0, 1.0, 1.0, 1.0)
  white_ptr = Fiddle::Pointer.malloc(white.bytesize)
  white_ptr[0, white.bytesize] = white

  COM.call(
    $render_target, ID2D1RenderTarget_Clear, Fiddle::TYPE_VOID,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $render_target, white_ptr
  )

  draw_line = Fiddle::Function.new(
    unpack_ptr(Fiddle::Pointer.new(unpack_ptr(Fiddle::Pointer.new($render_target)[0, Fiddle::SIZEOF_VOIDP]))[ID2D1RenderTarget_DrawLine * Fiddle::SIZEOF_VOIDP, Fiddle::SIZEOF_VOIDP]),
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_FLOAT, Fiddle::TYPE_VOIDP],
    Fiddle::TYPE_VOID,
    Fiddle::SIZEOF_VOIDP == 8 ? Fiddle::Function::DEFAULT : Fiddle::Function::STDCALL
  )

  p1 = point2f_value(320.0, 120.0)
  p2 = point2f_value(480.0, 360.0)
  p3 = point2f_value(160.0, 360.0)

  draw_line.call($render_target, p1, p2, $brush, 2.0, 0)
  draw_line.call($render_target, p2, p3, $brush, 2.0, 0)
  draw_line.call($render_target, p3, p1, $brush, 2.0, 0)

  COM.call(
    $render_target, ID2D1RenderTarget_EndDraw, Fiddle::TYPE_LONG,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
    $render_target, 0, 0
  )
end

WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_UINT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  case msg
  when User32::WM_PAINT
    draw
    User32.ValidateRect(hwnd, 0)
    0
  when User32::WM_SIZE
    width = lparam & 0xFFFF
    height = (lparam >> 16) & 0xFFFF
    resize_render_target(width, height)
    0
  when User32::WM_DESTROY
    User32.PostQuitMessage(0)
    0
  else
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  end
end

puts '=== Direct2D Triangle (Ruby) ==='

hInstance = Kernel32.GetModuleHandleA(nil)
class_name = 'RubyD2D'

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
  0, class_name, 'Direct2D Triangle (Ruby)',
  User32::WS_OVERLAPPEDWINDOW,
  User32::CW_USEDEFAULT, User32::CW_USEDEFAULT,
  640, 480,
  0, 0, hInstance, nil
)
raise 'CreateWindowExA failed' if $hwnd == 0

User32.ShowWindow($hwnd, User32::SW_SHOW)
User32.UpdateWindow($hwnd)

init_d2d
User32.InvalidateRect($hwnd, 0, 0)

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
    Kernel32.Sleep(1)
  end
end

cleanup
puts '=== Program End ==='
