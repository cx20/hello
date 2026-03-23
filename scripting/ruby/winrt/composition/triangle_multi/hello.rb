require 'fiddle/import'
require 'pathname'

# Windows.UI.Composition multi-panel sample in Ruby.
#
# This script follows the Python WinRT reference architecture while keeping the
# Ruby-native rendering paths already implemented for OpenGL, D3D11, and Vulkan.
#
# - One Win32 host window with WS_EX_NOREDIRECTIONBITMAP
# - One shared D3D11 device
# - One Windows.UI.Composition Compositor + DesktopWindowTarget
# - Three SpriteVisual panels backed by DXGI composition swap chains
#   Panel 0: OpenGL 4.6 via WGL_NV_DX_interop
#   Panel 1: D3D11 triangle
#   Panel 2: Vulkan offscreen render copied into a D3D11 staging texture

module User32
  extend Fiddle::Importer
  dlload 'user32.dll'

  WS_OVERLAPPEDWINDOW = 0x00CF0000
  WS_EX_NOREDIRECTIONBITMAP = 0x00200000
  CS_OWNDC = 0x0020
  CW_USEDEFAULT = -2147483648
  SW_SHOW = 5
  WM_CLOSE = 0x0010
  WM_DESTROY = 0x0002
  WM_PAINT = 0x000F
  WM_QUIT = 0x0012
  PM_REMOVE = 0x0001

  typealias 'UINT', 'unsigned int'
  typealias 'DWORD', 'unsigned long'
  typealias 'USHORT', 'unsigned short'
  typealias 'UINTPTR', 'uintptr_t'
  typealias 'BOOL', 'int'

  WNDCLASSEX = struct([
    'UINT cbSize',
    'UINT style',
    'UINTPTR lpfnWndProc',
    'int cbClsExtra',
    'int cbWndExtra',
    'UINTPTR hInstance',
    'UINTPTR hIcon',
    'UINTPTR hCursor',
    'UINTPTR hbrBackground',
    'UINTPTR lpszMenuName',
    'UINTPTR lpszClassName',
    'UINTPTR hIconSm'
  ])

  MSG = struct([
    'UINTPTR hwnd',
    'UINT message',
    'UINTPTR wParam',
    'UINTPTR lParam',
    'DWORD time',
    'long x',
    'long y'
  ])

  RECT = struct(['long left', 'long top', 'long right', 'long bottom'])

  extern 'USHORT RegisterClassExA(void*)'
  extern 'UINTPTR CreateWindowExA(DWORD, const char*, const char*, DWORD, int, int, int, int, UINTPTR, UINTPTR, UINTPTR, void*)'
  extern 'int ShowWindow(UINTPTR, int)'
  extern 'int UpdateWindow(UINTPTR)'
  extern 'BOOL PeekMessageA(void*, UINTPTR, UINT, UINT, UINT)'
  extern 'int TranslateMessage(void*)'
  extern 'UINTPTR DispatchMessageA(void*)'
  extern 'void PostQuitMessage(int)'
  extern 'UINTPTR DefWindowProcA(UINTPTR, UINT, UINTPTR, UINTPTR)'
  extern 'UINTPTR GetDC(UINTPTR)'
  extern 'int ReleaseDC(UINTPTR, UINTPTR)'
  extern 'BOOL GetClientRect(UINTPTR, void*)'
end

module Gdi32
  extend Fiddle::Importer
  dlload 'gdi32.dll'

  PFD_TYPE_RGBA = 0
  PFD_MAIN_PLANE = 0
  PFD_DRAW_TO_WINDOW = 0x00000004
  PFD_SUPPORT_OPENGL = 0x00000020
  PFD_DOUBLEBUFFER = 0x00000001

  PIXELFORMATDESCRIPTOR = struct([
    'unsigned short nSize',
    'unsigned short nVersion',
    'unsigned long dwFlags',
    'char iPixelType',
    'char cColorBits',
    'char cRedBits',
    'char cRedShift',
    'char cGreenBits',
    'char cGreenShift',
    'char cBlueBits',
    'char cBlueShift',
    'char cAlphaBits',
    'char cAlphaShift',
    'char cAccumBits',
    'char cAccumRedBits',
    'char cAccumGreenBits',
    'char cAccumBlueBits',
    'char cAccumAlphaBits',
    'char cDepthBits',
    'char cStencilBits',
    'char cAuxBuffers',
    'char iLayerType',
    'char bReserved',
    'unsigned long dwLayerMask',
    'unsigned long dwVisibleMask',
    'unsigned long dwDamageMask'
  ])

  extern 'int ChoosePixelFormat(uintptr_t, void*)'
  extern 'int SetPixelFormat(uintptr_t, int, void*)'
end

module OpenGL
  extend Fiddle::Importer
  dlload 'opengl32.dll'

  GL_COLOR_BUFFER_BIT = 0x00004000
  GL_TRIANGLES = 0x0004
  GL_FALSE = 0
  GL_FLOAT = 0x1406
  GL_ARRAY_BUFFER = 0x8892
  GL_STATIC_DRAW = 0x88E4
  GL_VERTEX_SHADER = 0x8B31
  GL_FRAGMENT_SHADER = 0x8B30
  GL_COMPILE_STATUS = 0x8B81
  GL_LINK_STATUS = 0x8B82
  GL_INFO_LOG_LENGTH = 0x8B84
  GL_VERSION = 0x1F02
  GL_SHADING_LANGUAGE_VERSION = 0x8B8C
  GL_FRAMEBUFFER = 0x8D40
  GL_RENDERBUFFER = 0x8D41
  GL_COLOR_ATTACHMENT0 = 0x8CE0

  WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091
  WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092
  WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126
  WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
  WGL_ACCESS_READ_WRITE_NV = 0x0001

  extern 'uintptr_t wglCreateContext(uintptr_t)'
  extern 'int wglMakeCurrent(uintptr_t, uintptr_t)'
  extern 'int wglDeleteContext(uintptr_t)'
  extern 'uintptr_t wglGetProcAddress(const char*)'

  extern 'void glClearColor(float, float, float, float)'
  extern 'void glClear(unsigned long)'
  extern 'void glViewport(int, int, int, int)'
  extern 'uintptr_t glGetString(unsigned long)'
  extern 'void glFlush()'
end

module GL46
  @fn = {}

  module_function

  def load_proc(name, ret, args)
    addr = OpenGL.wglGetProcAddress(name)
    raise "wglGetProcAddress failed: #{name}" if addr == 0
    @fn[name] = Fiddle::Function.new(addr, args, ret)
  end

  def init
    load_proc('wglCreateContextAttribsARB', Fiddle::TYPE_UINTPTR_T,
              [Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_VOIDP])
    load_proc('glCreateShader', Fiddle::TYPE_UINT, [Fiddle::TYPE_UINT])
    load_proc('glShaderSource', Fiddle::TYPE_VOID,
              [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
    load_proc('glCompileShader', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT])
    load_proc('glGetShaderiv', Fiddle::TYPE_VOID,
              [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
    load_proc('glGetShaderInfoLog', Fiddle::TYPE_VOID,
              [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
    load_proc('glCreateProgram', Fiddle::TYPE_UINT, [])
    load_proc('glAttachShader', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
    load_proc('glLinkProgram', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT])
    load_proc('glGetProgramiv', Fiddle::TYPE_VOID,
              [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
    load_proc('glGetProgramInfoLog', Fiddle::TYPE_VOID,
              [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
    load_proc('glUseProgram', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT])
    load_proc('glGenVertexArrays', Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
    load_proc('glBindVertexArray', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT])
    load_proc('glGenBuffers', Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
    load_proc('glBindBuffer', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
    load_proc('glBufferData', Fiddle::TYPE_VOID,
              [Fiddle::TYPE_UINT, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT])
    load_proc('glVertexAttribPointer', Fiddle::TYPE_VOID,
              [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_UINT, Fiddle::TYPE_UCHAR, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
    load_proc('glEnableVertexAttribArray', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT])
    load_proc('glDrawArrays', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_INT])
  end

  def call(name, *args)
    @fn[name].call(*args)
  end
end

module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'unsigned long GetLastError()'
  extern 'void OutputDebugStringA(const char*)'
  extern 'void Sleep(unsigned long)'
end

module Ole32
  extend Fiddle::Importer
  dlload 'ole32.dll'
  extern 'long CoInitializeEx(void*, unsigned long)'
  extern 'void CoUninitialize()'
end

module Combase
  extend Fiddle::Importer
  dlload 'combase.dll'
  extern 'long RoInitialize(unsigned int)'
  extern 'void RoUninitialize()'
  extern 'long RoActivateInstance(uintptr_t, void*)'
  extern 'long WindowsCreateStringReference(void*, unsigned int, void*, void*)'
end

module CoreMessaging
  extend Fiddle::Importer
  dlload 'CoreMessaging.dll'
  extern 'long CreateDispatcherQueueController(void*, void*)'
end

module D3D11
  extend Fiddle::Importer
  dlload 'd3d11.dll'

  D3D11_SDK_VERSION = 7
  D3D_DRIVER_TYPE_HARDWARE = 1
  D3D_FEATURE_LEVEL_11_0 = 0xB000
  D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20
  D3D11_USAGE_STAGING = 3
  D3D11_CPU_ACCESS_WRITE = 0x00010000
  D3D11_MAP_WRITE = 2

  extern 'long D3D11CreateDevice(void*, unsigned int, void*, unsigned int, void*, unsigned int, unsigned int, void*, void*, void*)'
end

module DXGI
  DXGI_FORMAT_B8G8R8A8_UNORM = 87
  DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20
  DXGI_SCALING_STRETCH = 0
  DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3
  DXGI_ALPHA_MODE_PREMULTIPLIED = 1
  DXGI_ALPHA_MODE_IGNORE = 3
end

module D3DCompiler
  extend Fiddle::Importer
  dlload 'd3dcompiler_47.dll'
  extern 'long D3DCompile(void*, size_t, const char*, void*, void*, const char*, const char*, unsigned int, unsigned int, void*, void*)'
end

module COM
  module_function

  def call(obj, index, ret_type, arg_types, *args)
    return 0 if obj.nil? || obj == 0
    vtbl_ptr = Fiddle::Pointer.new(obj)[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    fn_ptr = Fiddle::Pointer.new(vtbl_ptr)[index * Fiddle::SIZEOF_VOIDP, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    Fiddle::Function.new(fn_ptr, arg_types, ret_type).call(*args)
  end

  def release(obj)
    return if obj.nil? || obj == 0
    call(obj, 2, Fiddle::TYPE_ULONG, [Fiddle::TYPE_VOIDP], obj)
  end

  def qi(obj, iid)
    out = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
    hr = call(obj, 0, Fiddle::TYPE_LONG,
              [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
              obj, iid.to_i, out)
    raise format('QueryInterface failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
    out[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  end
end

PANEL_W = 320
PANEL_H = 480
WINDOW_W = PANEL_W * 3
WINDOW_H = PANEL_H
SCRIPT_DIR = Pathname.new(__FILE__).dirname

$quit = false
$hwnd = 0
$device = 0
$ctx = 0
$dq_controller = 0
$comp_unk = 0
$comp = 0
$desk_target = 0
$comp_target = 0
$root_container = 0
$root_visual = 0
$children = 0
$wuc_objects = []
$frame_count = 0
$keep_alive = []
$gl_pf_set = false

RO_INIT_SINGLETHREADED = 0
COINIT_APARTMENTTHREADED = 0x2
S_FALSE = 1
RPC_E_CHANGED_MODE = 0x80010106
DQTYPE_THREAD_CURRENT = 2
DQTAT_COM_STA = 2

def guid_from_string(text)
  a = text.delete('-')
  bytes = [a].pack('H*').bytes
  le = [
    bytes[3], bytes[2], bytes[1], bytes[0],
    bytes[5], bytes[4],
    bytes[7], bytes[6]
  ] + bytes[8, 8]
  Fiddle::Pointer[le.pack('C*')]
end

IID_ICompositor = guid_from_string('B403CA50-7F8C-4E83-985F-A414D26F1DAD')
IID_ICompositorDesktopInterop = guid_from_string('29E691FA-4567-4DCA-B319-D0F207EB6807')
IID_ICompositorInterop = guid_from_string('25297D5C-3AD4-4C9C-B5CF-E36A38512330')
IID_ICompositionTarget = guid_from_string('A1BEA8BA-D726-4663-8129-6B5E7927FFA6')
IID_IVisual = guid_from_string('117E202D-A859-4C89-873B-C2AA566788E3')
IID_ICompositionBrush = guid_from_string('AB0D7608-30C0-40E9-B568-B60A6BD1FB46')

def log(msg)
  text = "[RubyWUC] #{msg}"
  puts text
  Kernel32.OutputDebugStringA(text + "\n")
end

def keep(ptr)
  $keep_alive << ptr
  ptr
end

def cstr(str)
  keep(Fiddle::Pointer[(str.to_s + "\0")])
end

def wstr(str)
  # Build NUL-terminated UTF-16LE in one conversion to avoid encoding mismatch.
  keep(Fiddle::Pointer[(str.to_s + "\0").encode('UTF-16LE')])
end

def create_hstring(str)
  wide = wstr(str)
  utf16_len = str.to_s.encode('UTF-16LE').bytesize / 2
  header = keep(Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP * 5))
  hs_out = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = Combase.WindowsCreateStringReference(wide, utf16_len, header, hs_out)
  raise format('WindowsCreateStringReference failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  hs_out[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
end

def check_hr(hr, what)
  raise format('%s failed: 0x%08X', what, hr & 0xFFFFFFFF) if hr < 0
end

def write_u32(ptr, offset, value)
  ptr[offset, 4] = [value].pack('L')
end

def write_i32(ptr, offset, value)
  ptr[offset, 4] = [value].pack('l')
end

def write_u64(ptr, offset, value)
  ptr[offset, 8] = [value].pack('Q')
end

def write_f32(ptr, offset, value)
  ptr[offset, 4] = [value].pack('f')
end

def read_u32(ptr, offset)
  ptr[offset, 4].unpack1('L')
end

def read_u64(ptr, offset)
  ptr[offset, 8].unpack1('Q')
end

def gl_proc(name, ret_type, arg_types)
  addr = OpenGL.wglGetProcAddress(name)
  raise "wglGetProcAddress failed: #{name}" if addr == 0
  Fiddle::Function.new(addr, arg_types, ret_type)
end

def compile_gl_shader(type, source)
  shader = GL46.call('glCreateShader', type)
  src_ptr = Fiddle::Pointer[source]
  src_ptr_ptr = Fiddle::Pointer[[src_ptr.to_i].pack('Q')]
  src_len = Fiddle::Pointer[[source.bytesize].pack('l')]
  GL46.call('glShaderSource', shader, 1, src_ptr_ptr, src_len)
  GL46.call('glCompileShader', shader)

  status = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
  GL46.call('glGetShaderiv', shader, OpenGL::GL_COMPILE_STATUS, status)
  ok = status[0, Fiddle::SIZEOF_INT].unpack1('l')
  if ok != 1
    len = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL46.call('glGetShaderiv', shader, OpenGL::GL_INFO_LOG_LENGTH, len)
    log_len = len[0, Fiddle::SIZEOF_INT].unpack1('l')
    if log_len > 1
      buf = Fiddle::Pointer.malloc(log_len)
      out_len = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      GL46.call('glGetShaderInfoLog', shader, log_len, out_len, buf)
      raise "OpenGL shader compile failed: #{buf.to_s}"
    end
    raise 'OpenGL shader compile failed'
  end
  shader
end

def link_gl_program(vs, fs)
  prog = GL46.call('glCreateProgram')
  GL46.call('glAttachShader', prog, vs)
  GL46.call('glAttachShader', prog, fs)
  GL46.call('glLinkProgram', prog)

  status = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
  GL46.call('glGetProgramiv', prog, OpenGL::GL_LINK_STATUS, status)
  ok = status[0, Fiddle::SIZEOF_INT].unpack1('l')
  if ok != 1
    len = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL46.call('glGetProgramiv', prog, OpenGL::GL_INFO_LOG_LENGTH, len)
    log_len = len[0, Fiddle::SIZEOF_INT].unpack1('l')
    if log_len > 1
      buf = Fiddle::Pointer.malloc(log_len)
      out_len = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      GL46.call('glGetProgramInfoLog', prog, log_len, out_len, buf)
      raise "OpenGL program link failed: #{buf.to_s}"
    end
    raise 'OpenGL program link failed'
  end
  prog
end

def com_blob_ptr(blob)
  COM.call(blob, 3, Fiddle::TYPE_VOIDP, [Fiddle::TYPE_VOIDP], blob)
end

def com_blob_size(blob)
  COM.call(blob, 4, Fiddle::TYPE_SIZE_T, [Fiddle::TYPE_VOIDP], blob)
end

def msg_name(msg)
  case msg
  when User32::WM_CLOSE
    'WM_CLOSE'
  when User32::WM_DESTROY
    'WM_DESTROY'
  when User32::WM_QUIT
    'WM_QUIT'
  else
    format('0x%04X', msg)
  end
end

WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_UINT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  if msg == User32::WM_CLOSE || msg == User32::WM_DESTROY
    log("WndProc received #{msg_name(msg)}")
  end

  case msg
  when User32::WM_CLOSE, User32::WM_DESTROY
    $quit = true
    log('Posting WM_QUIT from WndProc')
    User32.PostQuitMessage(0)
    0
  else
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  end
end

def create_window
  hinst = Kernel32.GetModuleHandleA(nil)
  class_name = 'RubyDCompMulti'

  wc = User32::WNDCLASSEX.malloc
  wc.cbSize = User32::WNDCLASSEX.size
  wc.style = User32::CS_OWNDC
  wc.lpfnWndProc = WndProc.to_i
  wc.cbClsExtra = 0
  wc.cbWndExtra = 0
  wc.hInstance = hinst
  wc.hIcon = 0
  wc.hCursor = 0
  wc.hbrBackground = 0
  wc.lpszMenuName = 0
  wc.lpszClassName = Fiddle::Pointer[class_name].to_i
  wc.hIconSm = 0

  atom = User32.RegisterClassExA(wc)
  raise "RegisterClassExA failed: #{Kernel32.GetLastError()}" if atom == 0
  log("RegisterClassExA atom=#{atom}")

  $hwnd = User32.CreateWindowExA(
    User32::WS_EX_NOREDIRECTIONBITMAP, class_name,
    'OpenGL + D3D11 + Vulkan (Windows.UI.Composition / Ruby)',
    User32::WS_OVERLAPPEDWINDOW,
    User32::CW_USEDEFAULT,
    User32::CW_USEDEFAULT,
    WINDOW_W,
    WINDOW_H,
    0, 0, hinst, nil
  )
  raise "CreateWindowExA failed: #{Kernel32.GetLastError()}" if $hwnd == 0
  log(format('CreateWindowExA hwnd=0x%X', $hwnd))

  User32.ShowWindow($hwnd, User32::SW_SHOW)
  User32.UpdateWindow($hwnd)
  log('Window created')
end

def create_d3d11_device
  fl = [D3D11::D3D_FEATURE_LEVEL_11_0].pack('L')
  p_device = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  p_ctx = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)

  hr = D3D11.D3D11CreateDevice(
    nil,
    D3D11::D3D_DRIVER_TYPE_HARDWARE,
    nil,
    D3D11::D3D11_CREATE_DEVICE_BGRA_SUPPORT,
    fl,
    1,
    D3D11::D3D11_SDK_VERSION,
    p_device,
    nil,
    p_ctx
  )
  raise format('D3D11CreateDevice failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0

  $device = p_device[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  $ctx = p_ctx[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  log('D3D11 device created')
end

def create_comp_swapchain(width, height)
  iid_dxgi_device = guid_from_string('54EC77FA-1377-44E6-8C32-88FD5F44C84C')
  p_dxgi_device = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 0, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $device, iid_dxgi_device.to_i, p_dxgi_device)
  raise format('QI IDXGIDevice failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  dxgi_device = p_dxgi_device[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

  p_adapter = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(dxgi_device, 7, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], dxgi_device, p_adapter)
  raise format('GetAdapter failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  adapter = p_adapter[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

  iid_factory2 = guid_from_string('50C83A1C-E072-4C48-87B0-3630FA36A6D0')
  p_factory = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(adapter, 6, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                adapter, iid_factory2.to_i, p_factory)
  raise format('GetParent(IDXGIFactory2) failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  factory = p_factory[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

  alpha_modes = [DXGI::DXGI_ALPHA_MODE_PREMULTIPLIED, DXGI::DXGI_ALPHA_MODE_IGNORE]
  created_sc = 0
  last_hr = 0

  alpha_modes.each do |alpha_mode|
    # DXGI_SWAP_CHAIN_DESC1 (44 bytes)
    scd = Fiddle::Pointer.malloc(44)
    scd[0, 44] = "\0" * 44
    scd[0, 4] = [width].pack('L')
    scd[4, 4] = [height].pack('L')
    scd[8, 4] = [DXGI::DXGI_FORMAT_B8G8R8A8_UNORM].pack('L')
    scd[12, 4] = [0].pack('L') # Stereo = FALSE
    scd[16, 4] = [1].pack('L') # SampleDesc.Count
    scd[20, 4] = [0].pack('L') # SampleDesc.Quality
    scd[24, 4] = [DXGI::DXGI_USAGE_RENDER_TARGET_OUTPUT].pack('L')
    scd[28, 4] = [2].pack('L') # BufferCount
    scd[32, 4] = [DXGI::DXGI_SCALING_STRETCH].pack('L')
    scd[36, 4] = [DXGI::DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL].pack('L')
    scd[40, 4] = [alpha_mode].pack('L')

    p_sc = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
    hr = COM.call(factory, 24, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  factory, $device, scd, nil, p_sc)
    last_hr = hr

    if hr >= 0
      created_sc = p_sc[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
      log("CreateSwapChainForComposition succeeded (alpha=#{alpha_mode})")
      break
    else
      log(format('CreateSwapChainForComposition failed (alpha=%d): 0x%08X', alpha_mode, hr & 0xFFFFFFFF))
    end
  end

  if created_sc == 0
    COM.release(factory)
    COM.release(adapter)
    COM.release(dxgi_device)
    raise format('CreateSwapChainForComposition failed after retries: 0x%08X', last_hr & 0xFFFFFFFF)
  end

  COM.release(factory)
  COM.release(adapter)
  COM.release(dxgi_device)
  created_sc
end

def swapchain_get_buffer(sc)
  iid_tex = guid_from_string('6F15AAF2-D208-4E89-9AB4-489535D34F9C')
  p_tex = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call(sc, 9, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                sc, 0, iid_tex.to_i, p_tex)
  raise format('SwapChain GetBuffer failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  p_tex[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
end

def swapchain_present(sc)
  COM.call(sc, 8, Fiddle::TYPE_LONG,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT], sc, 1, 0)
end

def init_dispatcher_queue
  opts = Fiddle::Pointer.malloc(12)
  opts[0, 12] = "\0" * 12
  write_u32(opts, 0, 12)
  write_i32(opts, 4, DQTYPE_THREAD_CURRENT)
  write_i32(opts, 8, DQTAT_COM_STA)
  p_ctrl = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = CoreMessaging.CreateDispatcherQueueController(opts, p_ctrl)
  check_hr(hr, 'CreateDispatcherQueueController')
  $dq_controller = p_ctrl[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
end

def init_composition
  log('InitComposition: begin')

  hr = Ole32.CoInitializeEx(nil, COINIT_APARTMENTTHREADED)
  if hr < 0 && (hr & 0xFFFFFFFF) != RPC_E_CHANGED_MODE
    check_hr(hr, 'CoInitializeEx')
  end

  init_dispatcher_queue

  hr = Combase.RoInitialize(RO_INIT_SINGLETHREADED)
  if hr < 0 && hr != S_FALSE && (hr & 0xFFFFFFFF) != RPC_E_CHANGED_MODE
    check_hr(hr, 'RoInitialize')
  end

  hs = create_hstring('Windows.UI.Composition.Compositor')
  p_comp_unk = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = Combase.RoActivateInstance(hs, p_comp_unk)
  check_hr(hr, 'RoActivateInstance(Compositor)')
  $comp_unk = p_comp_unk[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  # Use the raw IInspectable directly as ICompositor - same vtable layout (ICompositor extends IInspectable).
  # Python reference does the same: g_compositor = inspectable (no QI for ICompositor).
  $comp = $comp_unk

  desk_interop = COM.qi($comp_unk, IID_ICompositorDesktopInterop)
  begin
    p_target = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
    hr = COM.call(desk_interop, 3, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
                  desk_interop, $hwnd, 0, p_target)
    check_hr(hr, 'CreateDesktopWindowTarget')
    $desk_target = p_target[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  ensure
    COM.release(desk_interop)
  end

  $comp_target = COM.qi($desk_target, IID_ICompositionTarget)

  p_root = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($comp, 9, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $comp, p_root)
  check_hr(hr, 'CreateContainerVisual')
  $root_container = p_root[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  $root_visual = COM.qi($root_container, IID_IVisual)

  hr = COM.call($comp_target, 7, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $comp_target, $root_visual)
  check_hr(hr, 'CompositionTarget.put_Root')

  p_children = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($root_container, 6, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $root_container, p_children)
  check_hr(hr, 'ContainerVisual.get_Children')
  $children = p_children[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

  log('InitComposition: ok')
end

def add_composition_panel(sc, offset_x, panel)
  comp_interop = COM.qi($comp_unk, IID_ICompositorInterop)
  begin
    p_surface = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
    hr = COM.call(comp_interop, 4, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  comp_interop, sc, p_surface)
    check_hr(hr, 'CreateCompositionSurfaceForSwapChain')
    surface = p_surface[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

    p_brush_raw = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
    hr = COM.call($comp, 24, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  $comp, surface, p_brush_raw)
    check_hr(hr, 'CreateSurfaceBrush')
    brush_raw = p_brush_raw[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    panel[:wuc_brush] = COM.qi(brush_raw, IID_ICompositionBrush)
    COM.release(brush_raw)
    COM.release(surface)

    p_sprite_raw = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
    hr = COM.call($comp, 22, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  $comp, p_sprite_raw)
    check_hr(hr, 'CreateSpriteVisual')
    panel[:sprite_raw] = p_sprite_raw[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

    hr = COM.call(panel[:sprite_raw], 7, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  panel[:sprite_raw], panel[:wuc_brush])
    check_hr(hr, 'SpriteVisual.put_Brush')

    panel[:vis] = COM.qi(panel[:sprite_raw], IID_IVisual)

    packed_size = [PANEL_W.to_f, PANEL_H.to_f].pack('f2').unpack1('Q')
    hr = COM.call(panel[:vis], 36, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG],
                  panel[:vis], packed_size)
    check_hr(hr, 'Visual.put_Size')

    offset = keep(Fiddle::Pointer.malloc(16))
    offset[0, 16] = [offset_x.to_f, 0.0, 0.0, 0.0].pack('f4')
    hr = COM.call(panel[:vis], 21, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  panel[:vis], offset)
    check_hr(hr, 'Visual.put_Offset')

    hr = COM.call($children, 9, Fiddle::TYPE_LONG,
                  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                  $children, panel[:vis])
    check_hr(hr, 'VisualCollection.InsertAtTop')

    $wuc_objects << panel[:wuc_brush] << panel[:sprite_raw] << panel[:vis]
  ensure
    COM.release(comp_interop)
  end
end

def create_rtv(tex)
  p_rtv = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 9, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $device, tex, nil, p_rtv)
  raise 'CreateRenderTargetView failed' if hr < 0
  p_rtv[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
end

def d3d_create_staging_tex(width, height)
  desc = Fiddle::Pointer.malloc(44)
  desc[0, 44] = "\0" * 44
  write_u32(desc, 0, width)
  write_u32(desc, 4, height)
  write_u32(desc, 8, 1)
  write_u32(desc, 12, 1)
  write_u32(desc, 16, DXGI::DXGI_FORMAT_B8G8R8A8_UNORM)
  write_u32(desc, 20, 1)
  write_u32(desc, 24, 0)
  write_u32(desc, 28, D3D11::D3D11_USAGE_STAGING)
  write_u32(desc, 32, 0)
  write_u32(desc, 36, D3D11::D3D11_CPU_ACCESS_WRITE)
  write_u32(desc, 40, 0)

  p_tex = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 5, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $device, desc, nil, p_tex)
  raise format('CreateTexture2D staging failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  p_tex[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
end

def ctx_copy_resource(dst, src)
  COM.call($ctx, 47, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $ctx, dst, src)
end

def ctx_map_write(res)
  mapped = Fiddle::Pointer.malloc(16)
  hr = COM.call($ctx, 14, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP],
                $ctx, res, 0, D3D11::D3D11_MAP_WRITE, 0, mapped)
  raise format('D3D11 Map failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  {
    p_data: read_u64(mapped, 0),
    row_pitch: read_u32(mapped, 8),
    depth_pitch: read_u32(mapped, 12)
  }
end

def ctx_unmap(res)
  COM.call($ctx, 15, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
           $ctx, res, 0)
end

class ShaderCompiler
  VERTEX = 0
  FRAGMENT = 1
  STATUS_SUCCESS = 0

  def initialize(dll_name = 'shaderc_shared.dll')
    path = resolve_path(dll_name)
    @lib = Fiddle.dlopen(path)
    @compiler_init = Fiddle::Function.new(@lib['shaderc_compiler_initialize'], [], Fiddle::TYPE_VOIDP)
    @compiler_release = Fiddle::Function.new(@lib['shaderc_compiler_release'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    @opts_init = Fiddle::Function.new(@lib['shaderc_compile_options_initialize'], [], Fiddle::TYPE_VOIDP)
    @opts_release = Fiddle::Function.new(@lib['shaderc_compile_options_release'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    @opts_set_opt = Fiddle::Function.new(@lib['shaderc_compile_options_set_optimization_level'], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_VOID)
    @compile = Fiddle::Function.new(@lib['shaderc_compile_into_spv'],
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
      Fiddle::TYPE_VOIDP)
    @res_release = Fiddle::Function.new(@lib['shaderc_result_release'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    @res_len = Fiddle::Function.new(@lib['shaderc_result_get_length'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_SIZE_T)
    @res_bytes = Fiddle::Function.new(@lib['shaderc_result_get_bytes'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
    @res_status = Fiddle::Function.new(@lib['shaderc_result_get_compilation_status'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
    @res_err = Fiddle::Function.new(@lib['shaderc_result_get_error_message'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
  end

  def compile_glsl(source_text, kind, filename)
    compiler = @compiler_init.call
    raise 'shaderc_compiler_initialize failed' if compiler == 0
    options = @opts_init.call
    raise 'shaderc_compile_options_initialize failed' if options == 0
    @opts_set_opt.call(options, 2)

    src = source_text.encode('utf-8')
    result = @compile.call(compiler, cstr(src).to_i, src.bytesize, kind, cstr(filename).to_i, cstr('main').to_i, options)
    raise 'shaderc_compile_into_spv returned NULL' if result == 0

    if @res_status.call(result) != STATUS_SUCCESS
      msg_ptr = @res_err.call(result)
      msg = msg_ptr == 0 ? '(no message)' : Fiddle::Pointer.new(msg_ptr).to_s
      @res_release.call(result)
      @opts_release.call(options)
      @compiler_release.call(compiler)
      raise "shaderc failed: #{msg}"
    end

    len = @res_len.call(result)
    bytes_ptr = @res_bytes.call(result)
    data = Fiddle::Pointer.new(bytes_ptr).to_s(len)

    @res_release.call(result)
    @opts_release.call(options)
    @compiler_release.call(compiler)
    data
  end

  private

  def resolve_path(name)
    local = (SCRIPT_DIR / name).to_s
    return local if File.exist?(local)
    sdk = ENV['VULKAN_SDK']
    if sdk
      cand = File.join(sdk, 'Bin', name)
      return cand if File.exist?(cand)
    end
    name
  end
end

VK_SUCCESS = 0
VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5
VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8
VK_STRUCTURE_TYPE_SUBMIT_INFO = 4
VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12
VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO = 14
VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15
VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16
VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22
VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28
VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30
VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37
VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38
VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39
VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40
VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42
VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43

VK_QUEUE_GRAPHICS_BIT = 0x00000001
VK_IMAGE_ASPECT_COLOR_BIT = 0x00000001
VK_FORMAT_B8G8R8A8_UNORM = 44
VK_IMAGE_TYPE_2D = 1
VK_IMAGE_TILING_OPTIMAL = 0
VK_IMAGE_USAGE_TRANSFER_SRC_BIT = 0x00000001
VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010
VK_SHARING_MODE_EXCLUSIVE = 0
VK_IMAGE_LAYOUT_UNDEFINED = 0
VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2
VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6
VK_IMAGE_VIEW_TYPE_2D = 1
VK_ATTACHMENT_LOAD_OP_CLEAR = 1
VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
VK_ATTACHMENT_STORE_OP_STORE = 0
VK_ATTACHMENT_STORE_OP_DONT_CARE = 1
VK_PIPELINE_BIND_POINT_GRAPHICS = 0
VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
VK_POLYGON_MODE_FILL = 0
VK_CULL_MODE_NONE = 0
VK_FRONT_FACE_COUNTER_CLOCKWISE = 1
VK_SAMPLE_COUNT_1_BIT = 1
VK_COLOR_COMPONENT_RGBA_BITS = 0xF
VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002
VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0
VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001
VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0x00000001
VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0x00000002
VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x00000004
VK_BUFFER_USAGE_TRANSFER_DST_BIT = 0x00000002

VK_LIB = Fiddle.dlopen('vulkan-1.dll')

def vk_fn(name, args, ret)
  Fiddle::Function.new(VK_LIB[name], args, ret)
end

VK_CREATE_INSTANCE = vk_fn('vkCreateInstance', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_ENUMERATE_PHYSICAL_DEVICES = vk_fn('vkEnumeratePhysicalDevices', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_GET_PHYSICAL_DEVICE_QUEUE_FAMILY_PROPERTIES = vk_fn('vkGetPhysicalDeviceQueueFamilyProperties', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_CREATE_DEVICE = vk_fn('vkCreateDevice', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_GET_DEVICE_QUEUE = vk_fn('vkGetDeviceQueue', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_GET_PHYSICAL_DEVICE_MEMORY_PROPERTIES = vk_fn('vkGetPhysicalDeviceMemoryProperties', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_CREATE_IMAGE = vk_fn('vkCreateImage', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_GET_IMAGE_MEMORY_REQUIREMENTS = vk_fn('vkGetImageMemoryRequirements', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_ALLOCATE_MEMORY = vk_fn('vkAllocateMemory', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_BIND_IMAGE_MEMORY = vk_fn('vkBindImageMemory', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG], Fiddle::TYPE_LONG)
VK_CREATE_IMAGE_VIEW = vk_fn('vkCreateImageView', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_CREATE_BUFFER = vk_fn('vkCreateBuffer', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_GET_BUFFER_MEMORY_REQUIREMENTS = vk_fn('vkGetBufferMemoryRequirements', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_BIND_BUFFER_MEMORY = vk_fn('vkBindBufferMemory', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG], Fiddle::TYPE_LONG)
VK_CREATE_RENDER_PASS = vk_fn('vkCreateRenderPass', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_CREATE_FRAMEBUFFER = vk_fn('vkCreateFramebuffer', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_CREATE_SHADER_MODULE = vk_fn('vkCreateShaderModule', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_DESTROY_SHADER_MODULE = vk_fn('vkDestroyShaderModule', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_CREATE_PIPELINE_LAYOUT = vk_fn('vkCreatePipelineLayout', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_CREATE_GRAPHICS_PIPELINES = vk_fn('vkCreateGraphicsPipelines', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_CREATE_COMMAND_POOL = vk_fn('vkCreateCommandPool', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_ALLOCATE_COMMAND_BUFFERS = vk_fn('vkAllocateCommandBuffers', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_CREATE_FENCE = vk_fn('vkCreateFence', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_WAIT_FOR_FENCES = vk_fn('vkWaitForFences', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_LONG_LONG], Fiddle::TYPE_LONG)
VK_RESET_FENCES = vk_fn('vkResetFences', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_RESET_COMMAND_BUFFER = vk_fn('vkResetCommandBuffer', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT], Fiddle::TYPE_LONG)
VK_BEGIN_COMMAND_BUFFER = vk_fn('vkBeginCommandBuffer', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_END_COMMAND_BUFFER = vk_fn('vkEndCommandBuffer', [Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_CMD_BEGIN_RENDER_PASS = vk_fn('vkCmdBeginRenderPass', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT], Fiddle::TYPE_VOID)
VK_CMD_END_RENDER_PASS = vk_fn('vkCmdEndRenderPass', [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_CMD_BIND_PIPELINE = vk_fn('vkCmdBindPipeline', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_CMD_DRAW = vk_fn('vkCmdDraw', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT], Fiddle::TYPE_VOID)
VK_CMD_COPY_IMAGE_TO_BUFFER = vk_fn('vkCmdCopyImageToBuffer', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_QUEUE_SUBMIT = vk_fn('vkQueueSubmit', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_MAP_MEMORY = vk_fn('vkMapMemory', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_LONG_LONG, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
VK_UNMAP_MEMORY = vk_fn('vkUnmapMemory', [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
VK_DEVICE_WAIT_IDLE = vk_fn('vkDeviceWaitIdle', [Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)

def vk_check(res, what)
  raise "#{what} failed: VkResult=#{res}" if res != VK_SUCCESS
end

def find_vk_memory_type(mem_props, type_bits, required_flags)
  type_count = read_u32(mem_props, 0)
  type_count.times do |index|
    flags = read_u32(mem_props, 4 + index * 8)
    return index if (type_bits & (1 << index)) != 0 && (flags & required_flags) == required_flags
  end
  raise 'No suitable Vulkan memory type found'
end

def compile_hlsl(src, entry, target)

  p_code = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  p_err = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  src_ptr = Fiddle::Pointer[src]
  hr = D3DCompiler.D3DCompile(
    src_ptr, src.bytesize, 'inline.hlsl', nil, nil,
    entry, target,
    0, 0,
    p_code, p_err
  )
  if hr < 0
    err_blob = p_err[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
    if err_blob != 0
      err_ptr = com_blob_ptr(err_blob)
      err_size = com_blob_size(err_blob)
      msg = Fiddle::Pointer.new(err_ptr).to_s(err_size)
      COM.release(err_blob)
      raise "D3DCompile #{entry}/#{target} failed: #{msg}"
    end
    raise format('D3DCompile %s/%s failed: 0x%08X', entry, target, hr & 0xFFFFFFFF)
  end

  code = p_code[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')
  [code, hr]
end

def init_d3d11_triangle_pipeline(panel)
  log('Init D3D11 triangle pipeline start')

  hlsl = <<~HLSL
    struct PSIn {
      float4 pos : SV_POSITION;
      float4 col : COLOR;
    };

    PSIn VS(uint vid : SV_VertexID)
    {
      float2 p[3] = {
        float2( 0.0,  0.5),
        float2( 0.5, -0.5),
        float2(-0.5, -0.5)
      };
      float4 c[3] = {
        float4(1,0,0,1),
        float4(0,1,0,1),
        float4(0,0,1,1)
      };
      PSIn o;
      o.pos = float4(p[vid], 0.0, 1.0);
      o.col = c[vid];
      return o;
    }

    float4 PS(PSIn i) : SV_Target
    {
      return i.col;
    }
  HLSL

  vs_blob, = compile_hlsl(hlsl, 'VS', 'vs_4_0')
  ps_blob, = compile_hlsl(hlsl, 'PS', 'ps_4_0')

  vs_ptr = com_blob_ptr(vs_blob)
  vs_size = com_blob_size(vs_blob)
  ps_ptr = com_blob_ptr(ps_blob)
  ps_size = com_blob_size(ps_blob)

  p_vs = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 12, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $device, vs_ptr, vs_size, nil, p_vs)
  raise format('CreateVertexShader failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  panel[:vs] = p_vs[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

  p_ps = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  hr = COM.call($device, 15, Fiddle::TYPE_LONG,
                [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
                $device, ps_ptr, ps_size, nil, p_ps)
  raise format('CreatePixelShader failed: 0x%08X', hr & 0xFFFFFFFF) if hr < 0
  panel[:ps] = p_ps[0, Fiddle::SIZEOF_VOIDP].unpack1('Q')

  # Static call buffers reused every frame.
  panel[:rtv_arr] = keep(Fiddle::Pointer[[panel[:rtv]].pack('Q')])
  panel[:vp] = keep(Fiddle::Pointer[[0.0, 0.0, PANEL_W.to_f, PANEL_H.to_f, 0.0, 1.0].pack('f6')])

  COM.release(vs_blob)
  COM.release(ps_blob)
  log('Init D3D11 triangle pipeline done')
end

def init_gl_interop_panel(panel)
  log('Init OpenGL interop panel start')

  hdc = User32.GetDC($hwnd)
  raise 'GetDC failed for OpenGL panel' if hdc == 0

  unless $gl_pf_set
    pfd = Gdi32::PIXELFORMATDESCRIPTOR.malloc
    pfd.nSize = Gdi32::PIXELFORMATDESCRIPTOR.size
    pfd.nVersion = 1
    pfd.dwFlags = Gdi32::PFD_DRAW_TO_WINDOW | Gdi32::PFD_SUPPORT_OPENGL | Gdi32::PFD_DOUBLEBUFFER
    pfd.iPixelType = Gdi32::PFD_TYPE_RGBA
    pfd.cColorBits = 32
    pfd.cDepthBits = 24
    pfd.iLayerType = Gdi32::PFD_MAIN_PLANE

    pf = Gdi32.ChoosePixelFormat(hdc, pfd)
    raise 'ChoosePixelFormat failed' if pf == 0
    raise 'SetPixelFormat failed' if Gdi32.SetPixelFormat(hdc, pf, pfd) == 0
    $gl_pf_set = true
  end

  hrc_old = OpenGL.wglCreateContext(hdc)
  raise 'wglCreateContext failed' if hrc_old == 0
  raise 'wglMakeCurrent failed' if OpenGL.wglMakeCurrent(hdc, hrc_old) == 0

  GL46.init
  attribs = [
    OpenGL::WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
    OpenGL::WGL_CONTEXT_MINOR_VERSION_ARB, 6,
    OpenGL::WGL_CONTEXT_PROFILE_MASK_ARB, OpenGL::WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
    0
  ].pack('l*')
  hrc = GL46.call('wglCreateContextAttribsARB', hdc, 0, Fiddle::Pointer[attribs])
  raise 'wglCreateContextAttribsARB failed' if hrc == 0
  raise 'wglMakeCurrent(GL4.6) failed' if OpenGL.wglMakeCurrent(hdc, hrc) == 0
  OpenGL.wglDeleteContext(hrc_old)

  gl_ver = OpenGL.glGetString(OpenGL::GL_VERSION)
  sl_ver = OpenGL.glGetString(OpenGL::GL_SHADING_LANGUAGE_VERSION)
  if gl_ver != 0
    log("OpenGL VERSION=#{Fiddle::Pointer.new(gl_ver).to_s}")
  end
  if sl_ver != 0
    log("GLSL VERSION=#{Fiddle::Pointer.new(sl_ver).to_s}")
  end

  wgl_dx_open = gl_proc('wglDXOpenDeviceNV', Fiddle::TYPE_VOIDP, [Fiddle::TYPE_VOIDP])
  wgl_dx_close = gl_proc('wglDXCloseDeviceNV', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP])
  wgl_dx_register = gl_proc('wglDXRegisterObjectNV', Fiddle::TYPE_VOIDP,
                            [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
  wgl_dx_unregister = gl_proc('wglDXUnregisterObjectNV', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
  wgl_dx_lock = gl_proc('wglDXLockObjectsNV', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
  wgl_dx_unlock = gl_proc('wglDXUnlockObjectsNV', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])

  gl_gen_rbo = gl_proc('glGenRenderbuffers', Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
  gl_bind_rbo = gl_proc('glBindRenderbuffer', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
  gl_gen_fbo = gl_proc('glGenFramebuffers', Fiddle::TYPE_VOID, [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
  gl_bind_fbo = gl_proc('glBindFramebuffer', Fiddle::TYPE_VOID, [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
  gl_fb_rbo = gl_proc('glFramebufferRenderbuffer', Fiddle::TYPE_VOID,
                      [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])

  interop_dev = wgl_dx_open.call($device)
  raise 'wglDXOpenDeviceNV failed' if interop_dev == 0

  p_rbo = Fiddle::Pointer.malloc(4)
  gl_gen_rbo.call(1, p_rbo)
  rbo = p_rbo[0, 4].unpack1('L')
  raise 'glGenRenderbuffers failed' if rbo == 0
  gl_bind_rbo.call(OpenGL::GL_RENDERBUFFER, rbo)

  interop_obj = wgl_dx_register.call(
    interop_dev,
    panel[:bb],
    rbo,
    OpenGL::GL_RENDERBUFFER,
    OpenGL::WGL_ACCESS_READ_WRITE_NV
  )
  raise 'wglDXRegisterObjectNV failed' if interop_obj == 0

  p_fbo = Fiddle::Pointer.malloc(4)
  gl_gen_fbo.call(1, p_fbo)
  fbo = p_fbo[0, 4].unpack1('L')
  raise 'glGenFramebuffers failed' if fbo == 0
  gl_bind_fbo.call(OpenGL::GL_FRAMEBUFFER, fbo)
  gl_fb_rbo.call(OpenGL::GL_FRAMEBUFFER, OpenGL::GL_COLOR_ATTACHMENT0, OpenGL::GL_RENDERBUFFER, rbo)
  gl_bind_fbo.call(OpenGL::GL_FRAMEBUFFER, 0)

  vs_src = "#version 460 core\nlayout(location=0) in vec3 pos;\nlayout(location=1) in vec3 col;\nout vec3 vCol;\nvoid main(){ vCol = col; gl_Position = vec4(pos.x, -pos.y, pos.z, 1.0); }\n"
  fs_src = "#version 460 core\nin vec3 vCol;\nout vec4 outColor;\nvoid main(){ outColor = vec4(vCol, 1.0); }\n"
  vs = compile_gl_shader(OpenGL::GL_VERTEX_SHADER, vs_src)
  fs = compile_gl_shader(OpenGL::GL_FRAGMENT_SHADER, fs_src)
  prog = link_gl_program(vs, fs)

  vao_buf = Fiddle::Pointer.malloc(4)
  GL46.call('glGenVertexArrays', 1, vao_buf)
  vao = vao_buf[0, 4].unpack1('L')
  GL46.call('glBindVertexArray', vao)

  vbos = Fiddle::Pointer.malloc(8)
  GL46.call('glGenBuffers', 2, vbos)
  vbo_pos = vbos[0, 4].unpack1('L')
  vbo_col = vbos[4, 4].unpack1('L')

  pos = keep(Fiddle::Pointer[[
    0.0, 0.5, 0.0,
    0.5, -0.5, 0.0,
    -0.5, -0.5, 0.0
  ].pack('f*')])
  col = keep(Fiddle::Pointer[[
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0
  ].pack('f*')])

  GL46.call('glBindBuffer', OpenGL::GL_ARRAY_BUFFER, vbo_pos)
  GL46.call('glBufferData', OpenGL::GL_ARRAY_BUFFER, 36, pos, OpenGL::GL_STATIC_DRAW)
  GL46.call('glVertexAttribPointer', 0, 3, OpenGL::GL_FLOAT, OpenGL::GL_FALSE, 0, nil)
  GL46.call('glEnableVertexAttribArray', 0)

  GL46.call('glBindBuffer', OpenGL::GL_ARRAY_BUFFER, vbo_col)
  GL46.call('glBufferData', OpenGL::GL_ARRAY_BUFFER, 36, col, OpenGL::GL_STATIC_DRAW)
  GL46.call('glVertexAttribPointer', 1, 3, OpenGL::GL_FLOAT, OpenGL::GL_FALSE, 0, nil)
  GL46.call('glEnableVertexAttribArray', 1)

  GL46.call('glBindVertexArray', 0)

  panel[:gl_hdc] = hdc
  panel[:gl_hrc] = hrc
  panel[:gl_interop_dev] = interop_dev
  panel[:gl_interop_obj] = interop_obj
  panel[:gl_rbo] = rbo
  panel[:gl_fbo] = fbo
  panel[:wgl_dx_close] = wgl_dx_close
  panel[:wgl_dx_unregister] = wgl_dx_unregister
  panel[:wgl_dx_lock] = wgl_dx_lock
  panel[:wgl_dx_unlock] = wgl_dx_unlock
  panel[:gl_bind_fbo] = gl_bind_fbo
  panel[:gl_program] = prog
  panel[:gl_vao] = vao
  panel[:gl_vbo_pos] = vbo_pos
  panel[:gl_vbo_col] = vbo_col

  log('Init OpenGL interop panel done')
end

def render_gl_interop_panel(panel, bg)
  return false unless panel[:gl_hrc] && panel[:gl_hrc] != 0

  OpenGL.wglMakeCurrent(panel[:gl_hdc], panel[:gl_hrc])

  obj_arr = Fiddle::Pointer[[panel[:gl_interop_obj]].pack('Q')]
  lock_ok = panel[:wgl_dx_lock].call(panel[:gl_interop_dev], 1, obj_arr)
  if lock_ok == 0
    log('wglDXLockObjectsNV failed; using fallback renderer for this frame')
    return false
  end

  panel[:gl_bind_fbo].call(OpenGL::GL_FRAMEBUFFER, panel[:gl_fbo])
  OpenGL.glViewport(0, 0, PANEL_W, PANEL_H)
  OpenGL.glClearColor(bg[0], bg[1], bg[2], 1.0)
  OpenGL.glClear(OpenGL::GL_COLOR_BUFFER_BIT)

  GL46.call('glUseProgram', panel[:gl_program])
  GL46.call('glBindVertexArray', panel[:gl_vao])
  GL46.call('glDrawArrays', OpenGL::GL_TRIANGLES, 0, 3)
  GL46.call('glBindVertexArray', 0)

  OpenGL.glFlush
  panel[:gl_bind_fbo].call(OpenGL::GL_FRAMEBUFFER, 0)

  panel[:wgl_dx_unlock].call(panel[:gl_interop_dev], 1, obj_arr)

  hr = swapchain_present(panel[:sc])
  if hr < 0
    log(format('OpenGL panel Present failed: 0x%08X', hr & 0xFFFFFFFF))
    return false
  end
  unless panel[:first_present_logged]
    log("#{panel[:name]} first present succeeded")
    panel[:first_present_logged] = true
  end
  true
end

def cleanup_gl_interop_panel(panel)
  return unless panel[:gl_hrc]

  if panel[:wgl_dx_unregister] && panel[:gl_interop_dev] && panel[:gl_interop_obj]
    panel[:wgl_dx_unregister].call(panel[:gl_interop_dev], panel[:gl_interop_obj])
  end
  if panel[:wgl_dx_close] && panel[:gl_interop_dev]
    panel[:wgl_dx_close].call(panel[:gl_interop_dev])
  end
  OpenGL.wglMakeCurrent(0, 0)
  OpenGL.wglDeleteContext(panel[:gl_hrc]) if panel[:gl_hrc] != 0
  User32.ReleaseDC($hwnd, panel[:gl_hdc]) if panel[:gl_hdc] && panel[:gl_hdc] != 0
end

def render_d3d11_triangle(panel)
  clear_rtv(panel[:rtv], 0.06, 0.22, 0.08, 1.0)

  COM.call($ctx, 33, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $ctx, 1, panel[:rtv_arr], nil)

  COM.call($ctx, 44, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP],
           $ctx, 1, panel[:vp])

  COM.call($ctx, 17, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $ctx, 0)

  COM.call($ctx, 24, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT], $ctx, 4)
  COM.call($ctx, 11, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
           $ctx, panel[:vs], nil, 0)
  COM.call($ctx, 9, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
           $ctx, panel[:ps], nil, 0)
  COM.call($ctx, 13, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT], $ctx, 3, 0)

  hr = swapchain_present(panel[:sc])
  if hr < 0
    log(format('D3D11 panel Present failed: 0x%08X', hr & 0xFFFFFFFF))
  elsif !panel[:first_present_logged]
    log("#{panel[:name]} first present succeeded")
    panel[:first_present_logged] = true
  end
end

def render_triangle_panel(panel, bg)
  clear_rtv(panel[:rtv], bg[0], bg[1], bg[2], 1.0)

  COM.call($ctx, 33, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $ctx, 1, panel[:rtv_arr], nil)

  COM.call($ctx, 44, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP],
           $ctx, 1, panel[:vp])

  COM.call($ctx, 17, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
           $ctx, 0)

  COM.call($ctx, 24, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT], $ctx, 4)
  COM.call($ctx, 11, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
           $ctx, panel[:vs], nil, 0)
  COM.call($ctx, 9, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT],
           $ctx, panel[:ps], nil, 0)
  COM.call($ctx, 13, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT], $ctx, 3, 0)

  hr = swapchain_present(panel[:sc])
  if hr < 0
    log(format('Triangle panel Present failed: 0x%08X', hr & 0xFFFFFFFF))
  elsif !panel[:first_present_logged]
    log("#{panel[:name]} first present succeeded")
    panel[:first_present_logged] = true
  end
end

def clear_rtv(rtv, r, g, b, a)
  color = [r, g, b, a].pack('f4')
  COM.call($ctx, 50, Fiddle::TYPE_VOID,
           [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], $ctx, rtv, color)
end

def present_panel(panel, rgb)
  clear_rtv(panel[:rtv], rgb[0], rgb[1], rgb[2], 1.0)
  hr = swapchain_present(panel[:sc])
  if hr && hr < 0
    log(format('Present failed: hr=0x%08X', hr & 0xFFFFFFFF))
  end
end

def create_panel(offset_x)
  sc = create_comp_swapchain(PANEL_W, PANEL_H)
  bb = swapchain_get_buffer(sc)
  rtv = create_rtv(bb)
  panel = { sc: sc, bb: bb, rtv: rtv }
  add_composition_panel(sc, offset_x, panel)
  panel
end

def init_vulkan_panel(panel)
  log('Init Vulkan panel start')

  compiler = ShaderCompiler.new
  vert_spv = compiler.compile_glsl((SCRIPT_DIR / 'hello.vert').read, ShaderCompiler::VERTEX, 'hello.vert')
  frag_spv = compiler.compile_glsl((SCRIPT_DIR / 'hello.frag').read, ShaderCompiler::FRAGMENT, 'hello.frag')

  app_info = Fiddle::Pointer.malloc(48)
  app_info[0, 48] = "\0" * 48
  write_u32(app_info, 0, VK_STRUCTURE_TYPE_APPLICATION_INFO)
  write_u64(app_info, 16, cstr('vk').to_i)
  write_u32(app_info, 24, 1)
  write_u64(app_info, 32, cstr('none').to_i)
  write_u32(app_info, 40, 1)
  write_u32(app_info, 44, (1 << 22))

  inst_ci = Fiddle::Pointer.malloc(64)
  inst_ci[0, 64] = "\0" * 64
  write_u32(inst_ci, 0, VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO)
  write_u64(inst_ci, 24, app_info.to_i)

  p_inst = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  vk_check(VK_CREATE_INSTANCE.call(inst_ci, nil, p_inst), 'vkCreateInstance')
  panel[:vk_instance] = read_u64(p_inst, 0)

  p_count = Fiddle::Pointer.malloc(4)
  vk_check(VK_ENUMERATE_PHYSICAL_DEVICES.call(panel[:vk_instance], p_count, nil), 'vkEnumeratePhysicalDevices(count)')
  dev_count = read_u32(p_count, 0)
  raise 'No Vulkan physical devices found' if dev_count == 0

  dev_list = Fiddle::Pointer.malloc(dev_count * 8)
  vk_check(VK_ENUMERATE_PHYSICAL_DEVICES.call(panel[:vk_instance], p_count, dev_list), 'vkEnumeratePhysicalDevices(list)')

  pd = 0
  qf_index = nil
  dev_count.times do |i|
    candidate = read_u64(dev_list, i * 8)
    q_count_ptr = Fiddle::Pointer.malloc(4)
    VK_GET_PHYSICAL_DEVICE_QUEUE_FAMILY_PROPERTIES.call(candidate, q_count_ptr, nil)
    q_count = read_u32(q_count_ptr, 0)
    next if q_count == 0
    q_props = Fiddle::Pointer.malloc(q_count * 24)
    VK_GET_PHYSICAL_DEVICE_QUEUE_FAMILY_PROPERTIES.call(candidate, q_count_ptr, q_props)
    q_count.times do |qi|
      flags = read_u32(q_props, qi * 24)
      if (flags & VK_QUEUE_GRAPHICS_BIT) != 0
        pd = candidate
        qf_index = qi
        break
      end
    end
    break if pd != 0
  end
  raise 'No Vulkan graphics queue family found' if pd == 0

  panel[:vk_physical_device] = pd
  panel[:vk_queue_family] = qf_index

  prio = keep(Fiddle::Pointer[[1.0].pack('f')])
  qci = Fiddle::Pointer.malloc(40)
  qci[0, 40] = "\0" * 40
  write_u32(qci, 0, VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO)
  write_u32(qci, 16, 0)
  write_u32(qci, 20, qf_index)
  write_u32(qci, 24, 1)
  write_u64(qci, 32, prio.to_i)

  dci = Fiddle::Pointer.malloc(72)
  dci[0, 72] = "\0" * 72
  write_u32(dci, 0, VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO)
  write_u32(dci, 20, 1)
  write_u64(dci, 24, qci.to_i)

  p_dev = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  vk_check(VK_CREATE_DEVICE.call(pd, dci, nil, p_dev), 'vkCreateDevice')
  panel[:vk_device] = read_u64(p_dev, 0)

  p_queue = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  VK_GET_DEVICE_QUEUE.call(panel[:vk_device], qf_index, 0, p_queue)
  panel[:vk_queue] = read_u64(p_queue, 0)

  mem_props = Fiddle::Pointer.malloc(520)
  mem_props[0, 520] = "\0" * 520
  VK_GET_PHYSICAL_DEVICE_MEMORY_PROPERTIES.call(pd, mem_props)

  img_ci = Fiddle::Pointer.malloc(88)
  img_ci[0, 88] = "\0" * 88
  write_u32(img_ci, 0, VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO)
  write_u32(img_ci, 20, VK_IMAGE_TYPE_2D)
  write_u32(img_ci, 24, VK_FORMAT_B8G8R8A8_UNORM)
  write_u32(img_ci, 28, PANEL_W)
  write_u32(img_ci, 32, PANEL_H)
  write_u32(img_ci, 36, 1)
  write_u32(img_ci, 40, 1)
  write_u32(img_ci, 44, 1)
  write_u32(img_ci, 48, VK_SAMPLE_COUNT_1_BIT)
  write_u32(img_ci, 52, VK_IMAGE_TILING_OPTIMAL)
  write_u32(img_ci, 56, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT)
  write_u32(img_ci, 60, VK_SHARING_MODE_EXCLUSIVE)
  write_u32(img_ci, 64, 0)
  write_u64(img_ci, 72, 0)
  write_u32(img_ci, 80, VK_IMAGE_LAYOUT_UNDEFINED)

  p_off_img = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_IMAGE.call(panel[:vk_device], img_ci, nil, p_off_img), 'vkCreateImage')
  panel[:vk_off_image] = read_u64(p_off_img, 0)

  mem_req = Fiddle::Pointer.malloc(24)
  mem_req[0, 24] = "\0" * 24
  VK_GET_IMAGE_MEMORY_REQUIREMENTS.call(panel[:vk_device], panel[:vk_off_image], mem_req)
  img_mem_ai = Fiddle::Pointer.malloc(32)
  img_mem_ai[0, 32] = "\0" * 32
  write_u32(img_mem_ai, 0, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO)
  write_u64(img_mem_ai, 16, read_u64(mem_req, 0))
  write_u32(img_mem_ai, 24, find_vk_memory_type(mem_props, read_u32(mem_req, 16), VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))

  p_off_mem = Fiddle::Pointer.malloc(8)
  vk_check(VK_ALLOCATE_MEMORY.call(panel[:vk_device], img_mem_ai, nil, p_off_mem), 'vkAllocateMemory(image)')
  panel[:vk_off_memory] = read_u64(p_off_mem, 0)
  vk_check(VK_BIND_IMAGE_MEMORY.call(panel[:vk_device], panel[:vk_off_image], panel[:vk_off_memory], 0), 'vkBindImageMemory')

  iv_ci = Fiddle::Pointer.malloc(80)
  iv_ci[0, 80] = "\0" * 80
  write_u32(iv_ci, 0, VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO)
  write_u64(iv_ci, 24, panel[:vk_off_image])
  write_u32(iv_ci, 32, VK_IMAGE_VIEW_TYPE_2D)
  write_u32(iv_ci, 36, VK_FORMAT_B8G8R8A8_UNORM)
  write_u32(iv_ci, 56, VK_IMAGE_ASPECT_COLOR_BIT)
  write_u32(iv_ci, 60, 0)
  write_u32(iv_ci, 64, 1)
  write_u32(iv_ci, 68, 0)
  write_u32(iv_ci, 72, 1)

  p_off_view = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_IMAGE_VIEW.call(panel[:vk_device], iv_ci, nil, p_off_view), 'vkCreateImageView')
  panel[:vk_off_view] = read_u64(p_off_view, 0)

  buf_ci = Fiddle::Pointer.malloc(56)
  buf_ci[0, 56] = "\0" * 56
  write_u32(buf_ci, 0, VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO)
  write_u64(buf_ci, 24, PANEL_W * PANEL_H * 4)
  write_u32(buf_ci, 32, VK_BUFFER_USAGE_TRANSFER_DST_BIT)
  write_u32(buf_ci, 36, VK_SHARING_MODE_EXCLUSIVE)

  p_read_buf = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_BUFFER.call(panel[:vk_device], buf_ci, nil, p_read_buf), 'vkCreateBuffer')
  panel[:vk_readback_buffer] = read_u64(p_read_buf, 0)

  buf_req = Fiddle::Pointer.malloc(24)
  buf_req[0, 24] = "\0" * 24
  VK_GET_BUFFER_MEMORY_REQUIREMENTS.call(panel[:vk_device], panel[:vk_readback_buffer], buf_req)
  buf_ai = Fiddle::Pointer.malloc(32)
  buf_ai[0, 32] = "\0" * 32
  write_u32(buf_ai, 0, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO)
  write_u64(buf_ai, 16, read_u64(buf_req, 0))
  host_flags = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
  write_u32(buf_ai, 24, find_vk_memory_type(mem_props, read_u32(buf_req, 16), host_flags))

  p_read_mem = Fiddle::Pointer.malloc(8)
  vk_check(VK_ALLOCATE_MEMORY.call(panel[:vk_device], buf_ai, nil, p_read_mem), 'vkAllocateMemory(buffer)')
  panel[:vk_readback_memory] = read_u64(p_read_mem, 0)
  vk_check(VK_BIND_BUFFER_MEMORY.call(panel[:vk_device], panel[:vk_readback_buffer], panel[:vk_readback_memory], 0), 'vkBindBufferMemory')

  att = Fiddle::Pointer.malloc(36)
  att[0, 36] = "\0" * 36
  write_u32(att, 4, VK_FORMAT_B8G8R8A8_UNORM)
  write_u32(att, 8, VK_SAMPLE_COUNT_1_BIT)
  write_u32(att, 12, VK_ATTACHMENT_LOAD_OP_CLEAR)
  write_u32(att, 16, VK_ATTACHMENT_STORE_OP_STORE)
  write_u32(att, 20, VK_ATTACHMENT_LOAD_OP_DONT_CARE)
  write_u32(att, 24, VK_ATTACHMENT_STORE_OP_DONT_CARE)
  write_u32(att, 28, VK_IMAGE_LAYOUT_UNDEFINED)
  write_u32(att, 32, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL)

  att_ref = Fiddle::Pointer.malloc(8)
  att_ref[0, 8] = "\0" * 8
  write_u32(att_ref, 0, 0)
  write_u32(att_ref, 4, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)

  sub = Fiddle::Pointer.malloc(72)
  sub[0, 72] = "\0" * 72
  write_u32(sub, 4, VK_PIPELINE_BIND_POINT_GRAPHICS)
  write_u32(sub, 24, 1)
  write_u64(sub, 32, att_ref.to_i)

  rp_ci = Fiddle::Pointer.malloc(64)
  rp_ci[0, 64] = "\0" * 64
  write_u32(rp_ci, 0, VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO)
  write_u32(rp_ci, 20, 1)
  write_u64(rp_ci, 24, att.to_i)
  write_u32(rp_ci, 32, 1)
  write_u64(rp_ci, 40, sub.to_i)

  p_rp = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_RENDER_PASS.call(panel[:vk_device], rp_ci, nil, p_rp), 'vkCreateRenderPass')
  panel[:vk_render_pass] = read_u64(p_rp, 0)

  fb_atts = keep(Fiddle::Pointer[[panel[:vk_off_view]].pack('Q')])
  fb_ci = Fiddle::Pointer.malloc(64)
  fb_ci[0, 64] = "\0" * 64
  write_u32(fb_ci, 0, VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO)
  write_u64(fb_ci, 24, panel[:vk_render_pass])
  write_u32(fb_ci, 32, 1)
  write_u64(fb_ci, 40, fb_atts.to_i)
  write_u32(fb_ci, 48, PANEL_W)
  write_u32(fb_ci, 52, PANEL_H)
  write_u32(fb_ci, 56, 1)

  p_fb = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_FRAMEBUFFER.call(panel[:vk_device], fb_ci, nil, p_fb), 'vkCreateFramebuffer')
  panel[:vk_framebuffer] = read_u64(p_fb, 0)

  vert_words = keep(Fiddle::Pointer[vert_spv])
  frag_words = keep(Fiddle::Pointer[frag_spv])
  sm_ci_vs = Fiddle::Pointer.malloc(40)
  sm_ci_vs[0, 40] = "\0" * 40
  write_u32(sm_ci_vs, 0, VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO)
  write_u64(sm_ci_vs, 24, vert_spv.bytesize)
  write_u64(sm_ci_vs, 32, vert_words.to_i)
  p_vs_mod = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_SHADER_MODULE.call(panel[:vk_device], sm_ci_vs, nil, p_vs_mod), 'vkCreateShaderModule(vs)')
  vs_mod = read_u64(p_vs_mod, 0)

  sm_ci_fs = Fiddle::Pointer.malloc(40)
  sm_ci_fs[0, 40] = "\0" * 40
  write_u32(sm_ci_fs, 0, VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO)
  write_u64(sm_ci_fs, 24, frag_spv.bytesize)
  write_u64(sm_ci_fs, 32, frag_words.to_i)
  p_fs_mod = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_SHADER_MODULE.call(panel[:vk_device], sm_ci_fs, nil, p_fs_mod), 'vkCreateShaderModule(fs)')
  fs_mod = read_u64(p_fs_mod, 0)

  stages = Fiddle::Pointer.malloc(96)
  stages[0, 96] = "\0" * 96
  write_u32(stages, 0, VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO)
  write_u32(stages, 16, 0)
  write_u32(stages, 20, 1)
  write_u64(stages, 24, vs_mod)
  write_u64(stages, 32, cstr('main').to_i)
  write_u32(stages, 48, VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO)
  write_u32(stages, 64, 0)
  write_u32(stages, 68, 0x10)
  write_u64(stages, 72, fs_mod)
  write_u64(stages, 80, cstr('main').to_i)

  vi = Fiddle::Pointer.malloc(48)
  vi[0, 48] = "\0" * 48
  write_u32(vi, 0, VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO)

  ia = Fiddle::Pointer.malloc(32)
  ia[0, 32] = "\0" * 32
  write_u32(ia, 0, VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO)
  write_u32(ia, 16, 0)
  write_u32(ia, 20, VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST)

  vp = Fiddle::Pointer.malloc(24)
  vp[0, 24] = "\0" * 24
  write_f32(vp, 0, 0.0)
  write_f32(vp, 4, 0.0)
  write_f32(vp, 8, PANEL_W.to_f)
  write_f32(vp, 12, PANEL_H.to_f)
  write_f32(vp, 16, 0.0)
  write_f32(vp, 20, 1.0)

  sc = Fiddle::Pointer.malloc(16)
  sc[0, 16] = "\0" * 16
  write_i32(sc, 0, 0)
  write_i32(sc, 4, 0)
  write_u32(sc, 8, PANEL_W)
  write_u32(sc, 12, PANEL_H)

  vp_state = Fiddle::Pointer.malloc(48)
  vp_state[0, 48] = "\0" * 48
  write_u32(vp_state, 0, VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO)
  write_u32(vp_state, 20, 1)
  write_u64(vp_state, 24, vp.to_i)
  write_u32(vp_state, 32, 1)
  write_u64(vp_state, 40, sc.to_i)

  rs = Fiddle::Pointer.malloc(64)
  rs[0, 64] = "\0" * 64
  write_u32(rs, 0, VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO)
  write_u32(rs, 20, 0)
  write_u32(rs, 24, 0)
  write_u32(rs, 28, VK_POLYGON_MODE_FILL)
  write_u32(rs, 32, VK_CULL_MODE_NONE)
  write_u32(rs, 36, VK_FRONT_FACE_COUNTER_CLOCKWISE)
  write_u32(rs, 40, 0)
  write_f32(rs, 56, 1.0)

  ms = Fiddle::Pointer.malloc(48)
  ms[0, 48] = "\0" * 48
  write_u32(ms, 0, VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO)
  write_u32(ms, 20, VK_SAMPLE_COUNT_1_BIT)

  cb_att = Fiddle::Pointer.malloc(32)
  cb_att[0, 32] = "\0" * 32
  write_u32(cb_att, 28, VK_COLOR_COMPONENT_RGBA_BITS)

  cb_state = Fiddle::Pointer.malloc(56)
  cb_state[0, 56] = "\0" * 56
  write_u32(cb_state, 0, VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO)
  write_u32(cb_state, 20, 0)
  write_u32(cb_state, 24, 0)
  write_u32(cb_state, 28, 1)
  write_u64(cb_state, 32, cb_att.to_i)

  pl_ci = Fiddle::Pointer.malloc(48)
  pl_ci[0, 48] = "\0" * 48
  write_u32(pl_ci, 0, VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO)
  p_layout = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_PIPELINE_LAYOUT.call(panel[:vk_device], pl_ci, nil, p_layout), 'vkCreatePipelineLayout')
  panel[:vk_pipeline_layout] = read_u64(p_layout, 0)

  gp_ci = Fiddle::Pointer.malloc(144)
  gp_ci[0, 144] = "\0" * 144
  write_u32(gp_ci, 0, VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO)
  write_u32(gp_ci, 20, 2)
  write_u64(gp_ci, 24, stages.to_i)
  write_u64(gp_ci, 32, vi.to_i)
  write_u64(gp_ci, 40, ia.to_i)
  write_u64(gp_ci, 56, vp_state.to_i)
  write_u64(gp_ci, 64, rs.to_i)
  write_u64(gp_ci, 72, ms.to_i)
  write_u64(gp_ci, 88, cb_state.to_i)
  write_u64(gp_ci, 104, panel[:vk_pipeline_layout])
  write_u64(gp_ci, 112, panel[:vk_render_pass])

  p_pipeline = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_GRAPHICS_PIPELINES.call(panel[:vk_device], 0, 1, gp_ci, nil, p_pipeline), 'vkCreateGraphicsPipelines')
  panel[:vk_pipeline] = read_u64(p_pipeline, 0)
  VK_DESTROY_SHADER_MODULE.call(panel[:vk_device], vs_mod, nil)
  VK_DESTROY_SHADER_MODULE.call(panel[:vk_device], fs_mod, nil)

  cp_ci = Fiddle::Pointer.malloc(24)
  cp_ci[0, 24] = "\0" * 24
  write_u32(cp_ci, 0, VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO)
  write_u32(cp_ci, 16, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT)
  write_u32(cp_ci, 20, qf_index)
  p_cmd_pool = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  vk_check(VK_CREATE_COMMAND_POOL.call(panel[:vk_device], cp_ci, nil, p_cmd_pool), 'vkCreateCommandPool')
  panel[:vk_cmd_pool] = read_u64(p_cmd_pool, 0)

  cb_ai = Fiddle::Pointer.malloc(32)
  cb_ai[0, 32] = "\0" * 32
  write_u32(cb_ai, 0, VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO)
  write_u64(cb_ai, 16, panel[:vk_cmd_pool])
  write_u32(cb_ai, 24, VK_COMMAND_BUFFER_LEVEL_PRIMARY)
  write_u32(cb_ai, 28, 1)
  p_cmd_buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  vk_check(VK_ALLOCATE_COMMAND_BUFFERS.call(panel[:vk_device], cb_ai, p_cmd_buf), 'vkAllocateCommandBuffers')
  panel[:vk_cmd_buf] = read_u64(p_cmd_buf, 0)

  fence_ci = Fiddle::Pointer.malloc(24)
  fence_ci[0, 24] = "\0" * 24
  write_u32(fence_ci, 0, VK_STRUCTURE_TYPE_FENCE_CREATE_INFO)
  write_u32(fence_ci, 16, VK_FENCE_CREATE_SIGNALED_BIT)
  p_fence = Fiddle::Pointer.malloc(8)
  vk_check(VK_CREATE_FENCE.call(panel[:vk_device], fence_ci, nil, p_fence), 'vkCreateFence')
  panel[:vk_fence] = read_u64(p_fence, 0)

  panel[:vk_staging_tex] = d3d_create_staging_tex(PANEL_W, PANEL_H)
  panel[:vk_buffer_size] = PANEL_W * PANEL_H * 4
  log('Init Vulkan panel done')
end

def render_vulkan_panel(panel)
  fences = Fiddle::Pointer[[panel[:vk_fence]].pack('Q')]
  vk_check(VK_WAIT_FOR_FENCES.call(panel[:vk_device], 1, fences, 1, -1), 'vkWaitForFences')
  vk_check(VK_RESET_FENCES.call(panel[:vk_device], 1, fences), 'vkResetFences')
  vk_check(VK_RESET_COMMAND_BUFFER.call(panel[:vk_cmd_buf], 0), 'vkResetCommandBuffer')

  cb_bi = Fiddle::Pointer.malloc(32)
  cb_bi[0, 32] = "\0" * 32
  write_u32(cb_bi, 0, VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO)
  vk_check(VK_BEGIN_COMMAND_BUFFER.call(panel[:vk_cmd_buf], cb_bi), 'vkBeginCommandBuffer')

  clear = Fiddle::Pointer.malloc(16)
  clear[0, 16] = [0.15, 0.05, 0.05, 1.0].pack('f4')
  rp_bi = Fiddle::Pointer.malloc(64)
  rp_bi[0, 64] = "\0" * 64
  write_u32(rp_bi, 0, VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO)
  write_u64(rp_bi, 16, panel[:vk_render_pass])
  write_u64(rp_bi, 24, panel[:vk_framebuffer])
  write_i32(rp_bi, 32, 0)
  write_i32(rp_bi, 36, 0)
  write_u32(rp_bi, 40, PANEL_W)
  write_u32(rp_bi, 44, PANEL_H)
  write_u32(rp_bi, 48, 1)
  write_u64(rp_bi, 56, clear.to_i)

  VK_CMD_BEGIN_RENDER_PASS.call(panel[:vk_cmd_buf], rp_bi, 0)
  VK_CMD_BIND_PIPELINE.call(panel[:vk_cmd_buf], VK_PIPELINE_BIND_POINT_GRAPHICS, panel[:vk_pipeline])
  VK_CMD_DRAW.call(panel[:vk_cmd_buf], 3, 1, 0, 0)
  VK_CMD_END_RENDER_PASS.call(panel[:vk_cmd_buf])

  region = Fiddle::Pointer.malloc(56)
  region[0, 56] = "\0" * 56
  write_u32(region, 8, PANEL_W)
  write_u32(region, 12, PANEL_H)
  write_u32(region, 16, VK_IMAGE_ASPECT_COLOR_BIT)
  write_u32(region, 20, 0)
  write_u32(region, 24, 0)
  write_u32(region, 28, 1)
  write_i32(region, 32, 0)
  write_i32(region, 36, 0)
  write_i32(region, 40, 0)
  write_u32(region, 44, PANEL_W)
  write_u32(region, 48, PANEL_H)
  write_u32(region, 52, 1)
  VK_CMD_COPY_IMAGE_TO_BUFFER.call(panel[:vk_cmd_buf], panel[:vk_off_image], VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, panel[:vk_readback_buffer], 1, region)
  vk_check(VK_END_COMMAND_BUFFER.call(panel[:vk_cmd_buf]), 'vkEndCommandBuffer')

  cmd_arr = Fiddle::Pointer[[panel[:vk_cmd_buf]].pack('Q')]
  submit = Fiddle::Pointer.malloc(72)
  submit[0, 72] = "\0" * 72
  write_u32(submit, 0, VK_STRUCTURE_TYPE_SUBMIT_INFO)
  write_u32(submit, 40, 1)
  write_u64(submit, 48, cmd_arr.to_i)
  vk_check(VK_QUEUE_SUBMIT.call(panel[:vk_queue], 1, submit, panel[:vk_fence]), 'vkQueueSubmit')
  vk_check(VK_WAIT_FOR_FENCES.call(panel[:vk_device], 1, fences, 1, -1), 'vkWaitForFences(post-submit)')

  p_vk_data = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  vk_check(VK_MAP_MEMORY.call(panel[:vk_device], panel[:vk_readback_memory], 0, panel[:vk_buffer_size], 0, p_vk_data), 'vkMapMemory')
  vk_data = read_u64(p_vk_data, 0)
  mapped = ctx_map_write(panel[:vk_staging_tex])
  src = Fiddle::Pointer.new(vk_data)
  pitch = PANEL_W * 4
  PANEL_H.times do |y|
    row = src[y * pitch, pitch]
    Fiddle::Pointer.new(mapped[:p_data] + y * mapped[:row_pitch])[0, pitch] = row
  end
  ctx_unmap(panel[:vk_staging_tex])
  VK_UNMAP_MEMORY.call(panel[:vk_device], panel[:vk_readback_memory])

  ctx_copy_resource(panel[:bb], panel[:vk_staging_tex])
  hr = swapchain_present(panel[:sc])
  if hr < 0
    log(format('Vulkan panel Present failed: 0x%08X', hr & 0xFFFFFFFF))
    return false
  end
  unless panel[:first_present_logged]
    log("#{panel[:name]} first present succeeded")
    panel[:first_present_logged] = true
  end
  true
end

def cleanup_vulkan_panel(panel)
  return unless panel[:vk_device]
  VK_DEVICE_WAIT_IDLE.call(panel[:vk_device])
  COM.release(panel[:vk_staging_tex]) if panel[:vk_staging_tex]
end

def validate_vulkan_runtime
  begin
    vk = Fiddle.dlopen('vulkan-1.dll')
    fn = Fiddle::Function.new(vk['vkEnumerateInstanceVersion'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
    p_ver = Fiddle::Pointer.malloc(4)
    if fn.call(p_ver) == 0
      v = p_ver[0, 4].unpack1('L')
      major = (v >> 22) & 0x3ff
      minor = (v >> 12) & 0x3ff
      log("Vulkan runtime detected: #{major}.#{minor}")
    end
  rescue
    log('Vulkan runtime is not available. Vulkan panel stays in fallback mode.')
  end
end

def pump_messages
  msg = User32::MSG.malloc
  while User32.PeekMessageA(msg, 0, 0, 0, User32::PM_REMOVE) != 0
    if msg.message == User32::WM_QUIT
      log('pump_messages got WM_QUIT')
      return false
    end
    if msg.message == User32::WM_CLOSE || msg.message == User32::WM_DESTROY
      log("pump_messages dispatch #{msg_name(msg.message)}")
    end
    User32.TranslateMessage(msg)
    User32.DispatchMessageA(msg)
  end
  if $quit
    log('pump_messages sees quit flag true')
  end
  !$quit
end

def main
  log('=== Windows.UI.Composition Multi Panel (Ruby) ===')
  log('DebugView logging is enabled')
  create_window
  create_d3d11_device
  init_composition

  gl_panel = create_panel(0.0)
  dx_panel = create_panel(PANEL_W.to_f)
  vk_panel = create_panel((PANEL_W * 2).to_f)
  gl_panel[:name] = 'OpenGL panel'
  dx_panel[:name] = 'DirectX panel'
  vk_panel[:name] = 'Vulkan panel'

  gl_native = false
  begin
    init_gl_interop_panel(gl_panel)
    gl_native = true
  rescue => e
    log("OpenGL native path disabled: #{e.message}")
    init_d3d11_triangle_pipeline(gl_panel)
  end

  init_d3d11_triangle_pipeline(dx_panel)

  vk_native = false
  begin
    init_vulkan_panel(vk_panel)
    vk_native = true
  rescue => e
    log("Vulkan native path disabled: #{e.message}")
    init_d3d11_triangle_pipeline(vk_panel)
  end

  validate_vulkan_runtime
  log('Panels created. Entering render loop...')
  log('Current render path: triangles on all three panels')
  log(gl_native ? 'Left panel: OpenGL slot (native OpenGL via WGL_NV_DX_interop)' : 'Left panel: OpenGL slot (compatibility triangle via D3D11)')
  log('Center panel: DirectX slot (native D3D11 triangle)')
  log(vk_native ? 'Right panel: Vulkan slot (native Vulkan offscreen + D3D11 copy)' : 'Right panel: Vulkan slot (compatibility triangle via D3D11)')

  frame = 0
  while pump_messages
    # Panel 0: OpenGL slot
    if gl_native
      ok = render_gl_interop_panel(gl_panel, [0.06, 0.10, 0.28])
      render_triangle_panel(gl_panel, [0.06, 0.10, 0.28]) unless ok
    else
      render_triangle_panel(gl_panel, [0.06, 0.10, 0.28])
    end
    # Panel 1: D3D11 path triangle
    render_triangle_panel(dx_panel, [0.06, 0.22, 0.08])
    # Panel 2: Vulkan slot (compatibility triangle)
    if vk_native
      ok = render_vulkan_panel(vk_panel)
      render_triangle_panel(vk_panel, [0.24, 0.08, 0.08]) unless ok
    else
      render_triangle_panel(vk_panel, [0.24, 0.08, 0.08])
    end

    frame += 1
    $frame_count = frame
    log("Frame #{frame}") if (frame % 120).zero?
    Kernel32.Sleep(1)
  end

  log("Render loop exited at frame #{frame}")

  cleanup_gl_interop_panel(gl_panel)
  COM.release(gl_panel[:ps]); COM.release(gl_panel[:vs])
  COM.release(gl_panel[:rtv]); COM.release(gl_panel[:bb]); COM.release(gl_panel[:sc])
  COM.release(dx_panel[:ps]); COM.release(dx_panel[:vs])
  COM.release(dx_panel[:rtv]); COM.release(dx_panel[:bb]); COM.release(dx_panel[:sc])
  cleanup_vulkan_panel(vk_panel)
  COM.release(vk_panel[:ps]); COM.release(vk_panel[:vs])
  COM.release(vk_panel[:rtv]); COM.release(vk_panel[:bb]); COM.release(vk_panel[:sc])
  $wuc_objects.reverse_each { |obj| COM.release(obj) if obj && obj != 0 }
  COM.release($children); COM.release($root_visual); COM.release($root_container)
  COM.release($comp_target); COM.release($desk_target); COM.release($comp); COM.release($comp_unk)
  COM.release($dq_controller)
  COM.release($ctx); COM.release($device)

  begin
    Combase.RoUninitialize()
  rescue StandardError
  end
  begin
    Ole32.CoUninitialize()
  rescue StandardError
  end

  log('=== END ===')
end

begin
  main
rescue => e
  warn "ERROR: #{e.message}"
  warn e.backtrace.join("\n")
  exit 1
end
                                                                                                                                                                                                                                                                                                