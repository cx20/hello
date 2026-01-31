require 'fiddle/import'

# User32.dll - Windows User Interface API
module User32
  extend Fiddle::Importer
  dlload 'user32.dll'
  
  # Window Style Constants
  WS_OVERLAPPEDWINDOW = 0x00CF0000
  
  # Class Style Constants
  CS_OWNDC = 0x0020
  
  # Window Position Constants
  CW_USEDEFAULT = -2147483648
  
  # Window Message Constants
  WM_DESTROY  = 0x0002
  WM_CLOSE    = 0x0010
  WM_QUIT     = 0x0012
  WM_NCCREATE = 0x0081
  
  # PeekMessage Constants
  PM_REMOVE = 0x0001
  
  # ShowWindow Constants
  SW_SHOW = 5
  
  # Type Aliases
  typealias 'UINT',    'unsigned int'
  typealias 'DWORD',   'unsigned long'
  typealias 'LONG',    'long'
  typealias 'USHORT',  'unsigned short'
  typealias 'UINTPTR', 'uintptr_t'
  typealias 'BOOL',    'int'
  
  # WNDCLASSEX Structure
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
  
  # MSG Structure
  MSG = struct([
    'UINTPTR hwnd',
    'UINT    message',
    'UINTPTR wParam',
    'UINTPTR lParam',
    'DWORD   time',
    'long    x',
    'long    y'
  ])
  
  # Function Declarations
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
  
  # PixelFormat Constants
  PFD_TYPE_RGBA      = 0
  PFD_MAIN_PLANE     = 0
  PFD_DRAW_TO_WINDOW = 0x00000004
  PFD_SUPPORT_OPENGL = 0x00000020
  PFD_DOUBLEBUFFER   = 0x00000001
  
  # Type Aliases
  typealias 'DWORD', 'unsigned long'
  typealias 'WORD',  'unsigned short'
  typealias 'BOOL',  'int'
  
  # PIXELFORMATDESCRIPTOR Structure
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
  GL_COLOR_BUFFER_BIT = 0x00004000
  GL_FLOAT            = 0x1406
  GL_TRIANGLE_STRIP   = 0x0005
  GL_VERTEX_ARRAY     = 0x8074
  GL_COLOR_ARRAY      = 0x8076
  
  # Type Aliases
  typealias 'DWORD',  'unsigned long'
  typealias 'BOOL',   'int'
  typealias 'GLenum', 'unsigned int'
  typealias 'GLint',  'int'
  typealias 'GLsizei','int'
  
  # WGL Functions
  extern 'uintptr_t wglCreateContext(uintptr_t)'
  extern 'BOOL      wglMakeCurrent(uintptr_t, uintptr_t)'
  extern 'BOOL      wglDeleteContext(uintptr_t)'
  
  # OpenGL 1.0 Functions
  extern 'void glClearColor(float, float, float, float)'
  extern 'void glClear(DWORD)'
  
  # OpenGL 1.1 Vertex Array Functions
  extern 'void glEnableClientState(GLenum)'
  extern 'void glDisableClientState(GLenum)'
  extern 'void glVertexPointer(GLint, GLenum, GLsizei, void*)'
  extern 'void glColorPointer(GLint, GLenum, GLsizei, void*)'
  extern 'void glDrawArrays(GLenum, GLint, GLsizei)'
end

# Kernel32.dll - Windows Kernel API
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  
  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'unsigned long GetLastError()'
  extern 'void Sleep(unsigned long)'
end

# Enable OpenGL rendering context
def enable_opengl(hdc)
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
  if fmt == 0
    raise "ChoosePixelFormat failed (GetLastError=#{Kernel32.GetLastError()})"
  end
  puts "ChoosePixelFormat: format=#{fmt}"
  
  if Gdi32.SetPixelFormat(hdc, fmt, pfd) == 0
    raise "SetPixelFormat failed (GetLastError=#{Kernel32.GetLastError()})"
  end
  puts "SetPixelFormat: success"
  
  hrc = OpenGL.wglCreateContext(hdc)
  if hrc == 0
    raise "wglCreateContext failed (GetLastError=#{Kernel32.GetLastError()})"
  end
  puts "wglCreateContext: hrc=#{hrc}"
  
  if OpenGL.wglMakeCurrent(hdc, hrc) == 0
    raise "wglMakeCurrent failed (GetLastError=#{Kernel32.GetLastError()})"
  end
  puts "wglMakeCurrent: success"
  
  hrc
end

# Disable OpenGL rendering context
def disable_opengl(hwnd, hdc, hrc)
  if hrc != 0
    OpenGL.wglMakeCurrent(0, 0)
    OpenGL.wglDeleteContext(hrc)
  end
  if hwnd != 0 && hdc != 0
    User32.ReleaseDC(hwnd, hdc)
  end
end

# Vertex data (x, y for each vertex)
VERTICES = [
   0.0,  0.5,   # Top
   0.5, -0.5,   # Bottom right
  -0.5, -0.5    # Bottom left
].pack('f*')

# Color data (r, g, b for each vertex)
COLORS = [
  1.0, 0.0, 0.0,  # Red
  0.0, 1.0, 0.0,  # Green
  0.0, 0.0, 1.0   # Blue
].pack('f*')

# Draw triangle using OpenGL 1.1 vertex arrays
def draw_triangle_gl11
  # Enable vertex and color arrays
  OpenGL.glEnableClientState(OpenGL::GL_COLOR_ARRAY)
  OpenGL.glEnableClientState(OpenGL::GL_VERTEX_ARRAY)
  
  # Set pointers to vertex data
  OpenGL.glColorPointer(3, OpenGL::GL_FLOAT, 0, COLORS)
  OpenGL.glVertexPointer(2, OpenGL::GL_FLOAT, 0, VERTICES)
  
  # Draw the triangle
  OpenGL.glDrawArrays(OpenGL::GL_TRIANGLE_STRIP, 0, 3)
  
  # Disable arrays
  OpenGL.glDisableClientState(OpenGL::GL_VERTEX_ARRAY)
  OpenGL.glDisableClientState(OpenGL::GL_COLOR_ARRAY)
end

# Window Procedure Callback
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
puts "=== OpenGL 1.1 Triangle (Ruby) ==="

# Get module handle
hInstance = Kernel32.GetModuleHandleA(nil)
puts "GetModuleHandleA: hInstance=#{hInstance}"

# Register window class
class_name = "RubyOpenGL11"

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
puts "RegisterClassExA: atom=#{atom}"

if atom == 0
  puts "Error: RegisterClassExA failed (GetLastError=#{Kernel32.GetLastError()})"
  exit 1
end

# Create window
hwnd = User32.CreateWindowExA(
  0,
  class_name,
  "OpenGL 1.1 Triangle (Ruby)",
  User32::WS_OVERLAPPEDWINDOW,
  User32::CW_USEDEFAULT,
  User32::CW_USEDEFAULT,
  640,
  480,
  0,
  0,
  hInstance,
  nil
)
puts "CreateWindowExA: hwnd=#{hwnd}"

if hwnd == 0
  puts "Error: CreateWindowExA failed (GetLastError=#{Kernel32.GetLastError()})"
  exit 1
end

# Show window
User32.ShowWindow(hwnd, User32::SW_SHOW)
puts "Window displayed"

# Get device context
hdc = User32.GetDC(hwnd)
if hdc == 0
  puts "Error: GetDC failed"
  exit 1
end
puts "GetDC: hdc=#{hdc}"

# Enable OpenGL
hrc = enable_opengl(hdc)

# Render loop using PeekMessage
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
    # Clear screen (black background)
    OpenGL.glClearColor(0.0, 0.0, 0.0, 0.0)
    OpenGL.glClear(OpenGL::GL_COLOR_BUFFER_BIT)
    
    # Draw triangle using vertex arrays
    draw_triangle_gl11
    
    # Swap buffers (double buffering)
    Gdi32.SwapBuffers(hdc)
    
    # Small delay to reduce CPU usage
    Kernel32.Sleep(1)
  end
end

# Cleanup
puts "Cleaning up..."
disable_opengl(hwnd, hdc, hrc)

puts "=== Program End ==="
