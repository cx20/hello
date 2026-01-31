require 'fiddle/import'

# User32.dll - Windows User Interface API
module User32
  extend Fiddle::Importer
  dlload 'user32.dll'
  
  # Constants
  WS_OVERLAPPEDWINDOW = 0x00CF0000
  CS_OWNDC            = 0x0020
  CW_USEDEFAULT       = -2147483648
  WM_DESTROY          = 0x0002
  WM_CLOSE            = 0x0010
  WM_QUIT             = 0x0012
  WM_NCCREATE         = 0x0081
  PM_REMOVE           = 0x0001
  SW_SHOW             = 5
  
  # Type Aliases
  typealias 'UINT',    'unsigned int'
  typealias 'DWORD',   'unsigned long'
  typealias 'LONG',    'long'
  typealias 'USHORT',  'unsigned short'
  typealias 'UINTPTR', 'uintptr_t'
  typealias 'BOOL',    'int'
  
  # Structures
  WNDCLASSEX = struct([
    'UINT    cbSize',
    'UINT    style',
    'UINTPTR lpfnWndProc',
    'int     cbClsExtra',
    'int     cbWndExtra',
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
    'UINT    message',
    'UINTPTR wParam',
    'UINTPTR lParam',
    'DWORD   time',
    'long    x',
    'long    y'
  ])
  
  # Functions
  extern 'USHORT  RegisterClassExA(void*)'
  extern 'UINTPTR CreateWindowExA(DWORD, const char*, const char*, DWORD, int, int, int, int, UINTPTR, UINTPTR, UINTPTR, void*)'
  extern 'int     ShowWindow(UINTPTR, int)'
  extern 'BOOL    PeekMessageA(void*, UINTPTR, UINT, UINT, UINT)'
  extern 'int     TranslateMessage(void*)'
  extern 'UINTPTR DispatchMessageA(void*)'
  extern 'void    PostQuitMessage(int)'
  extern 'UINTPTR DefWindowProcA(UINTPTR, UINT, UINTPTR, UINTPTR)'
  extern 'UINTPTR GetDC(UINTPTR)'
  extern 'int     ReleaseDC(UINTPTR, UINTPTR)'
end

# Gdi32.dll - Graphics Device Interface API
module Gdi32
  extend Fiddle::Importer
  dlload 'gdi32.dll'
  
  # Constants
  PFD_TYPE_RGBA      = 0
  PFD_MAIN_PLANE     = 0
  PFD_DRAW_TO_WINDOW = 0x00000004
  PFD_SUPPORT_OPENGL = 0x00000020
  PFD_DOUBLEBUFFER   = 0x00000001
  
  # Type Aliases
  typealias 'DWORD', 'unsigned long'
  typealias 'WORD',  'unsigned short'
  typealias 'BOOL',  'int'
  
  # Structures
  PIXELFORMATDESCRIPTOR = struct([
    'WORD  nSize',
    'WORD  nVersion',
    'DWORD dwFlags',
    'char  iPixelType',
    'char  cColorBits',
    'char  cRedBits',
    'char  cRedShift',
    'char  cGreenBits',
    'char  cGreenShift',
    'char  cBlueBits',
    'char  cBlueShift',
    'char  cAlphaBits',
    'char  cAlphaShift',
    'char  cAccumBits',
    'char  cAccumRedBits',
    'char  cAccumGreenBits',
    'char  cAccumBlueBits',
    'char  cAccumAlphaBits',
    'char  cDepthBits',
    'char  cStencilBits',
    'char  cAuxBuffers',
    'char  iLayerType',
    'char  bReserved',
    'DWORD dwLayerMask',
    'DWORD dwVisibleMask',
    'DWORD dwDamageMask'
  ])
  
  extern 'int  ChoosePixelFormat(uintptr_t, void*)'
  extern 'BOOL SetPixelFormat(uintptr_t, int, void*)'
  extern 'BOOL SwapBuffers(uintptr_t)'
end

# OpenGL32.dll - OpenGL API
module OpenGL
  extend Fiddle::Importer
  dlload 'opengl32.dll'
  
  # OpenGL Constants
  GL_COLOR_BUFFER_BIT  = 0x00004000
  GL_TRIANGLES         = 0x0004
  GL_FALSE             = 0
  GL_TRUE              = 1
  GL_FLOAT             = 0x1406
  GL_ARRAY_BUFFER      = 0x8892
  GL_STATIC_DRAW       = 0x88E4
  GL_FRAGMENT_SHADER   = 0x8B30
  GL_VERTEX_SHADER     = 0x8B31
  GL_COMPILE_STATUS    = 0x8B81
  GL_LINK_STATUS       = 0x8B82
  GL_INFO_LOG_LENGTH   = 0x8B84
  GL_VERSION           = 0x1F02
  GL_SHADING_LANGUAGE_VERSION = 0x8B8C
  
  # WGL Constants
  WGL_CONTEXT_MAJOR_VERSION_ARB    = 0x2091
  WGL_CONTEXT_MINOR_VERSION_ARB    = 0x2092
  WGL_CONTEXT_FLAGS_ARB            = 0x2094
  WGL_CONTEXT_PROFILE_MASK_ARB     = 0x9126
  WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001
  
  # Type Aliases
  typealias 'DWORD', 'unsigned long'
  typealias 'BOOL',  'int'
  
  # WGL Functions
  extern 'uintptr_t wglCreateContext(uintptr_t)'
  extern 'BOOL      wglMakeCurrent(uintptr_t, uintptr_t)'
  extern 'BOOL      wglDeleteContext(uintptr_t)'
  extern 'uintptr_t wglGetProcAddress(const char*)'
  
  # OpenGL 1.1 Functions
  extern 'void glClearColor(float, float, float, float)'
  extern 'void glClear(DWORD)'
  extern 'void glViewport(int, int, int, int)'
  extern 'uintptr_t glGetString(DWORD)'
end

# Kernel32.dll - Windows Kernel API
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  
  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'unsigned long GetLastError()'
  extern 'void Sleep(unsigned long)'
end

# OpenGL 4.6 Function Loader
module GL46
  @functions = {}
  
  def self.get_proc(name, ret_type, arg_types)
    addr = OpenGL.wglGetProcAddress(name)
    raise "wglGetProcAddress failed: #{name}" if addr == 0
    Fiddle::Function.new(addr, arg_types, ret_type)
  end
  
  def self.init
    # WGL extension
    @functions[:wglCreateContextAttribsARB] = get_proc(
      "wglCreateContextAttribsARB", Fiddle::TYPE_UINTPTR_T,
      [Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_VOIDP]
    )
    
    # VAO functions
    @functions[:glGenVertexArrays] = get_proc("glGenVertexArrays", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
    @functions[:glBindVertexArray] = get_proc("glBindVertexArray", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT])
    
    # VBO functions
    @functions[:glGenBuffers] = get_proc("glGenBuffers", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
    @functions[:glBindBuffer] = get_proc("glBindBuffer", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
    @functions[:glBufferData] = get_proc("glBufferData", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT])
    
    # Shader functions
    @functions[:glCreateShader] = get_proc("glCreateShader", Fiddle::TYPE_UINT,
      [Fiddle::TYPE_UINT])
    @functions[:glShaderSource] = get_proc("glShaderSource", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
    @functions[:glCompileShader] = get_proc("glCompileShader", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT])
    @functions[:glGetShaderiv] = get_proc("glGetShaderiv", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
    @functions[:glGetShaderInfoLog] = get_proc("glGetShaderInfoLog", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
    
    # Program functions
    @functions[:glCreateProgram] = get_proc("glCreateProgram", Fiddle::TYPE_UINT, [])
    @functions[:glAttachShader] = get_proc("glAttachShader", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
    @functions[:glLinkProgram] = get_proc("glLinkProgram", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT])
    @functions[:glUseProgram] = get_proc("glUseProgram", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT])
    @functions[:glGetProgramiv] = get_proc("glGetProgramiv", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
    @functions[:glGetProgramInfoLog] = get_proc("glGetProgramInfoLog", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
    
    # Vertex attribute functions
    @functions[:glVertexAttribPointer] = get_proc("glVertexAttribPointer", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_UINT, Fiddle::TYPE_UCHAR, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP])
    @functions[:glEnableVertexAttribArray] = get_proc("glEnableVertexAttribArray", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT])
    
    # Draw functions
    @functions[:glDrawArrays] = get_proc("glDrawArrays", Fiddle::TYPE_VOID,
      [Fiddle::TYPE_UINT, Fiddle::TYPE_INT, Fiddle::TYPE_INT])
    
    puts "OpenGL 4.6 functions loaded"
  end
  
  def self.call(name, *args)
    @functions[name].call(*args)
  end
  
  # Convenience methods
  def self.wglCreateContextAttribsARB(hdc, share, attribs) call(:wglCreateContextAttribsARB, hdc, share, attribs) end
  def self.glGenVertexArrays(n, arrays)    call(:glGenVertexArrays, n, arrays) end
  def self.glBindVertexArray(array)        call(:glBindVertexArray, array) end
  def self.glGenBuffers(n, buffers)        call(:glGenBuffers, n, buffers) end
  def self.glBindBuffer(target, buffer)    call(:glBindBuffer, target, buffer) end
  def self.glBufferData(target, size, data, usage) call(:glBufferData, target, size, data, usage) end
  def self.glCreateShader(type)            call(:glCreateShader, type) end
  def self.glShaderSource(shader, count, string, length) call(:glShaderSource, shader, count, string, length) end
  def self.glCompileShader(shader)         call(:glCompileShader, shader) end
  def self.glGetShaderiv(shader, pname, params) call(:glGetShaderiv, shader, pname, params) end
  def self.glGetShaderInfoLog(shader, bufSize, length, infoLog) call(:glGetShaderInfoLog, shader, bufSize, length, infoLog) end
  def self.glCreateProgram()               call(:glCreateProgram) end
  def self.glAttachShader(program, shader) call(:glAttachShader, program, shader) end
  def self.glLinkProgram(program)          call(:glLinkProgram, program) end
  def self.glUseProgram(program)           call(:glUseProgram, program) end
  def self.glGetProgramiv(program, pname, params) call(:glGetProgramiv, program, pname, params) end
  def self.glGetProgramInfoLog(program, bufSize, length, infoLog) call(:glGetProgramInfoLog, program, bufSize, length, infoLog) end
  def self.glVertexAttribPointer(index, size, type, normalized, stride, pointer) call(:glVertexAttribPointer, index, size, type, normalized, stride, pointer) end
  def self.glEnableVertexAttribArray(index) call(:glEnableVertexAttribArray, index) end
  def self.glDrawArrays(mode, first, count) call(:glDrawArrays, mode, first, count) end
end

# Set pixel format
def set_pixel_format(hdc)
  pfd = Gdi32::PIXELFORMATDESCRIPTOR.malloc
  Fiddle::Pointer.new(pfd.to_ptr)[0, Gdi32::PIXELFORMATDESCRIPTOR.size] = "\0" * Gdi32::PIXELFORMATDESCRIPTOR.size
  
  pfd.nSize      = Gdi32::PIXELFORMATDESCRIPTOR.size
  pfd.nVersion   = 1
  pfd.dwFlags    = Gdi32::PFD_DRAW_TO_WINDOW | Gdi32::PFD_SUPPORT_OPENGL | Gdi32::PFD_DOUBLEBUFFER
  pfd.iPixelType = Gdi32::PFD_TYPE_RGBA
  pfd.cColorBits = 24
  pfd.cDepthBits = 16
  pfd.iLayerType = Gdi32::PFD_MAIN_PLANE
  
  fmt = Gdi32.ChoosePixelFormat(hdc, pfd)
  raise "ChoosePixelFormat failed" if fmt == 0
  raise "SetPixelFormat failed" if Gdi32.SetPixelFormat(hdc, fmt, pfd) == 0
end

# Create OpenGL 4.6 Core Profile context
def create_gl46_context(hdc)
  # Create legacy context first
  hrc_old = OpenGL.wglCreateContext(hdc)
  raise "wglCreateContext failed" if hrc_old == 0
  raise "wglMakeCurrent failed" if OpenGL.wglMakeCurrent(hdc, hrc_old) == 0
  
  # Load OpenGL 4.6 functions
  GL46.init
  
  # Create OpenGL 4.6 Core Profile context
  attribs = [
    OpenGL::WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
    OpenGL::WGL_CONTEXT_MINOR_VERSION_ARB, 6,
    OpenGL::WGL_CONTEXT_FLAGS_ARB, 0,
    OpenGL::WGL_CONTEXT_PROFILE_MASK_ARB, OpenGL::WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
    0
  ].pack('l*')
  
  hrc = GL46.wglCreateContextAttribsARB(hdc, 0, attribs)
  raise "wglCreateContextAttribsARB failed" if hrc == 0
  
  raise "wglMakeCurrent failed" if OpenGL.wglMakeCurrent(hdc, hrc) == 0
  OpenGL.wglDeleteContext(hrc_old)
  
  hrc
end

# Destroy context
def destroy_context(hwnd, hdc, hrc)
  if hrc != 0
    OpenGL.wglMakeCurrent(0, 0)
    OpenGL.wglDeleteContext(hrc)
  end
  User32.ReleaseDC(hwnd, hdc) if hwnd != 0 && hdc != 0
end

# Compile shader
def compile_shader(type, source)
  shader = GL46.glCreateShader(type)
  
  src_ptr = Fiddle::Pointer[source]
  src_ptr_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_VOIDP)
  src_ptr_ptr[0, Fiddle::SIZEOF_VOIDP] = [src_ptr.to_i].pack('Q')
  
  len_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
  len_ptr[0, Fiddle::SIZEOF_INT] = [source.bytesize].pack('l')
  
  GL46.glShaderSource(shader, 1, src_ptr_ptr, len_ptr)
  GL46.glCompileShader(shader)
  
  status_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
  GL46.glGetShaderiv(shader, OpenGL::GL_COMPILE_STATUS, status_ptr)
  status = status_ptr[0, Fiddle::SIZEOF_INT].unpack1('l')
  
  if status != 1
    log_len_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL46.glGetShaderiv(shader, OpenGL::GL_INFO_LOG_LENGTH, log_len_ptr)
    log_len = log_len_ptr[0, Fiddle::SIZEOF_INT].unpack1('l')
    
    if log_len > 1
      log_buf = Fiddle::Pointer.malloc(log_len)
      out_len_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      GL46.glGetShaderInfoLog(shader, log_len, out_len_ptr, log_buf)
      raise "Shader compile failed:\n#{log_buf.to_s}"
    end
    raise "Shader compile failed (no log)"
  end
  
  shader
end

# Link program
def link_program(vs, fs)
  program = GL46.glCreateProgram
  GL46.glAttachShader(program, vs)
  GL46.glAttachShader(program, fs)
  GL46.glLinkProgram(program)
  
  status_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
  GL46.glGetProgramiv(program, OpenGL::GL_LINK_STATUS, status_ptr)
  status = status_ptr[0, Fiddle::SIZEOF_INT].unpack1('l')
  
  if status != 1
    log_len_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL46.glGetProgramiv(program, OpenGL::GL_INFO_LOG_LENGTH, log_len_ptr)
    log_len = log_len_ptr[0, Fiddle::SIZEOF_INT].unpack1('l')
    
    if log_len > 1
      log_buf = Fiddle::Pointer.malloc(log_len)
      out_len_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
      GL46.glGetProgramInfoLog(program, log_len, out_len_ptr, log_buf)
      raise "Program link failed:\n#{log_buf.to_s}"
    end
    raise "Program link failed (no log)"
  end
  
  program
end

# GLSL 460 Core Shaders
VERTEX_SHADER_SOURCE = "#version 460 core
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
out vec3 vColor;
void main() {
    vColor = color;
    gl_Position = vec4(position, 1.0);
}
"

FRAGMENT_SHADER_SOURCE = "#version 460 core
in vec3 vColor;
layout(location = 0) out vec4 outColor;
void main() {
    outColor = vec4(vColor, 1.0);
}
"

# Vertex data
VERTICES = [
   0.0,  0.5, 0.0,
   0.5, -0.5, 0.0,
  -0.5, -0.5, 0.0
].pack('f*')

COLORS = [
  1.0, 0.0, 0.0,
  0.0, 1.0, 0.0,
  0.0, 0.0, 1.0
].pack('f*')

# Global variables
$vao = 0
$vbo = nil
$shader_program = 0

# Initialize triangle resources
def init_triangle_resources
  # Create VAO
  vao_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
  GL46.glGenVertexArrays(1, vao_ptr)
  $vao = vao_ptr[0, Fiddle::SIZEOF_INT].unpack1('L')
  GL46.glBindVertexArray($vao)
  puts "VAO created: #{$vao}"
  
  # Create VBOs
  vbo_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * 2)
  GL46.glGenBuffers(2, vbo_ptr)
  $vbo = vbo_ptr[0, Fiddle::SIZEOF_INT * 2].unpack('L2')
  puts "VBOs created: #{$vbo.inspect}"
  
  # Position buffer -> location 0
  GL46.glBindBuffer(OpenGL::GL_ARRAY_BUFFER, $vbo[0])
  GL46.glBufferData(OpenGL::GL_ARRAY_BUFFER, VERTICES.bytesize, VERTICES, OpenGL::GL_STATIC_DRAW)
  GL46.glVertexAttribPointer(0, 3, OpenGL::GL_FLOAT, OpenGL::GL_FALSE, 0, 0)
  GL46.glEnableVertexAttribArray(0)
  
  # Color buffer -> location 1
  GL46.glBindBuffer(OpenGL::GL_ARRAY_BUFFER, $vbo[1])
  GL46.glBufferData(OpenGL::GL_ARRAY_BUFFER, COLORS.bytesize, COLORS, OpenGL::GL_STATIC_DRAW)
  GL46.glVertexAttribPointer(1, 3, OpenGL::GL_FLOAT, OpenGL::GL_FALSE, 0, 0)
  GL46.glEnableVertexAttribArray(1)
  
  # Compile and link shaders
  puts "Compiling vertex shader..."
  vs = compile_shader(OpenGL::GL_VERTEX_SHADER, VERTEX_SHADER_SOURCE)
  puts "Compiling fragment shader..."
  fs = compile_shader(OpenGL::GL_FRAGMENT_SHADER, FRAGMENT_SHADER_SOURCE)
  
  puts "Linking program..."
  $shader_program = link_program(vs, fs)
  GL46.glUseProgram($shader_program)
  puts "Shader program: #{$shader_program}"
end

# Draw triangle
def draw
  GL46.glUseProgram($shader_program)
  GL46.glBindVertexArray($vao)
  GL46.glDrawArrays(OpenGL::GL_TRIANGLES, 0, 3)
end

# Window Procedure
WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_UINT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  case msg
  when User32::WM_NCCREATE
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  when User32::WM_CLOSE
    User32.PostQuitMessage(0)
    0
  when User32::WM_DESTROY
    0
  else
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  end
end

# Main Program
puts "=== OpenGL 4.6 Triangle (Ruby) ==="

hInstance = Kernel32.GetModuleHandleA(nil)
class_name = "RubyOpenGL46"

wc = User32::WNDCLASSEX.malloc
wc.cbSize        = User32::WNDCLASSEX.size
wc.style         = User32::CS_OWNDC
wc.lpfnWndProc   = WndProc.to_i
wc.cbClsExtra    = 0
wc.cbWndExtra    = 0
wc.hInstance     = hInstance
wc.hIcon         = 0
wc.hCursor       = 0
wc.hbrBackground = 0
wc.lpszMenuName  = 0
wc.lpszClassName = Fiddle::Pointer[class_name].to_i
wc.hIconSm       = 0

atom = User32.RegisterClassExA(wc)
raise "RegisterClassExA failed" if atom == 0

hwnd = User32.CreateWindowExA(
  0, class_name, "OpenGL 4.6 Triangle (Ruby)",
  User32::WS_OVERLAPPEDWINDOW,
  User32::CW_USEDEFAULT, User32::CW_USEDEFAULT,
  640, 480,
  0, 0, hInstance, nil
)
raise "CreateWindowExA failed" if hwnd == 0

User32.ShowWindow(hwnd, User32::SW_SHOW)

hdc = User32.GetDC(hwnd)
raise "GetDC failed" if hdc == 0

# Set pixel format and create OpenGL 4.6 context
set_pixel_format(hdc)
hrc = create_gl46_context(hdc)

# Print OpenGL version info
ver_ptr = OpenGL.glGetString(OpenGL::GL_VERSION)
sl_ptr = OpenGL.glGetString(OpenGL::GL_SHADING_LANGUAGE_VERSION)
ver_str = ver_ptr != 0 ? Fiddle::Pointer.new(ver_ptr).to_s : "(null)"
sl_str = sl_ptr != 0 ? Fiddle::Pointer.new(sl_ptr).to_s : "(null)"
puts "[GL] Version: #{ver_str}"
puts "[GL] GLSL: #{sl_str}"

# Set viewport
OpenGL.glViewport(0, 0, 640, 480)

# Initialize resources
init_triangle_resources

# Render loop
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
    OpenGL.glClearColor(0.0, 0.0, 0.0, 0.0)
    OpenGL.glClear(OpenGL::GL_COLOR_BUFFER_BIT)
    
    draw
    
    Gdi32.SwapBuffers(hdc)
    Kernel32.Sleep(1)
  end
end

puts "Cleaning up..."
destroy_context(hwnd, hdc, hrc)
puts "=== Program End ==="
