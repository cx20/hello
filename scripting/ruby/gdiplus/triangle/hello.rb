require 'fiddle/import'

# User32.dll - Windows User Interface API
module User32
  extend Fiddle::Importer
  dlload 'user32.dll'
  
  # Window Style Constants
  WS_OVERLAPPEDWINDOW = 0x00CF0000
  WS_VISIBLE          = 0x10000000
  
  # Class Style Constants
  CS_HREDRAW = 0x0002
  CS_VREDRAW = 0x0001
  
  # Window Position Constants
  CW_USEDEFAULT = -2147483648
  
  # Window Message Constants
  WM_DESTROY  = 0x0002
  WM_PAINT    = 0x000F
  WM_NCCREATE = 0x0081
  
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
  
  # PAINTSTRUCT Structure
  PAINTSTRUCT = struct([
    'UINTPTR hdc',
    'int     fErase',
    'long    left',
    'long    top',
    'long    right',
    'long    bottom',
    'int     fRestore',
    'int     fIncUpdate',
    'char    rgbReserved[32]'
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
  
  # RECT Structure
  RECT = struct([
    'long left',
    'long top',
    'long right',
    'long bottom'
  ])
  
  # Function Declarations
  extern 'USHORT  RegisterClassExA(void*)'
  extern 'UINTPTR CreateWindowExA(DWORD, const char*, const char*, DWORD, int, int, int, int, UINTPTR, UINTPTR, UINTPTR, void*)'
  extern 'int     ShowWindow(UINTPTR, int)'
  extern 'int     UpdateWindow(UINTPTR)'
  extern 'int     GetMessageA(void*, UINTPTR, UINT, UINT)'
  extern 'int     TranslateMessage(void*)'
  extern 'UINTPTR DispatchMessageA(void*)'
  extern 'void    PostQuitMessage(int)'
  extern 'UINTPTR DefWindowProcA(UINTPTR, UINT, UINTPTR, UINTPTR)'
  extern 'UINTPTR BeginPaint(UINTPTR, void*)'
  extern 'int     EndPaint(UINTPTR, void*)'
  extern 'BOOL    GetClientRect(UINTPTR, void*)'
  extern 'UINTPTR GetDC(UINTPTR)'
  extern 'int     ReleaseDC(UINTPTR, UINTPTR)'
end

# GDI.dll - Device Context Functions
module GDI32
  extend Fiddle::Importer
  dlload 'gdi32.dll'
  
  # Type Aliases
  typealias 'BOOL',    'int'
  typealias 'UINT',    'unsigned int'
  typealias 'UINTPTR', 'uintptr_t'
  typealias 'DWORD',   'unsigned long'
  
  extern 'UINTPTR GetStockObject(int)'
  extern 'BOOL    PatBlt(UINTPTR, int, int, int, int, DWORD)'
end

# GDI+ via gdiplus.dll
module GDIPlus
  extend Fiddle::Importer
  dlload 'gdiplus.dll'
  
  # Type Aliases
  typealias 'INT',      'int'
  typealias 'DWORD',    'unsigned long'
  typealias 'UINTPTR',  'uintptr_t'
  typealias 'GpStatus', 'int'
  
  # GDI+ Structures
  GdiplusStartupInput = struct([
    'unsigned int GdiplusVersion',
    'UINTPTR      DebugEventCallback',
    'int          SuppressBackgroundThread',
    'int          SuppressExternalCodecs'
  ])
  
  GpPoint = struct([
    'INT x',
    'INT y'
  ])
  
  # GDI+ Function Declarations
  extern 'GpStatus GdiplusStartup(UINTPTR*, void*, void*)'
  extern 'void     GdiplusShutdown(UINTPTR)'
  
  extern 'GpStatus GdipCreateFromHDC(UINTPTR, UINTPTR*)'
  extern 'GpStatus GdipDeleteGraphics(UINTPTR)'
  
  extern 'GpStatus GdipCreatePath(INT, UINTPTR*)'
  extern 'GpStatus GdipDeletePath(UINTPTR)'
  extern 'GpStatus GdipAddPathLine2I(UINTPTR, void*, INT)'
  extern 'GpStatus GdipClosePathFigure(UINTPTR)'
  
  extern 'GpStatus GdipCreatePathGradientFromPath(UINTPTR, UINTPTR*)'
  extern 'GpStatus GdipSetPathGradientCenterColor(UINTPTR, DWORD)'
  extern 'GpStatus GdipSetPathGradientSurroundColorsWithCount(UINTPTR, void*, INT*)'
  extern 'GpStatus GdipDeleteBrush(UINTPTR)'
  
  extern 'GpStatus GdipFillPath(UINTPTR, UINTPTR, UINTPTR)'
end

# Kernel32.dll - Windows Kernel API
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  
  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'unsigned long GetLastError()'
end

# Global GDI+ token
$gdip_token = nil

# Initialize GDI+
def gdiplus_startup
  startup_input = GDIPlus::GdiplusStartupInput.malloc
  startup_input.GdiplusVersion = 1
  startup_input.DebugEventCallback = 0
  startup_input.SuppressBackgroundThread = 0
  startup_input.SuppressExternalCodecs = 0
  
  token_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INTPTR_T)
  status = GDIPlus.GdiplusStartup(token_ptr, startup_input, nil)
  
  if status != 0
    puts "GdiplusStartup failed: #{status}"
    return false
  end
  
  $gdip_token = token_ptr[0, Fiddle::SIZEOF_INTPTR_T].unpack('Q')[0]
  true
end

# Shutdown GDI+
def gdiplus_shutdown
  GDIPlus.GdiplusShutdown($gdip_token) if $gdip_token
end

# Draw GDI+ gradient triangle
def draw_triangle_gdiplus(hdc, width, height)
  # Create graphics context from HDC
  graphics_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INTPTR_T)
  status = GDIPlus.GdipCreateFromHDC(hdc, graphics_ptr)
  return if status != 0
  
  graphics = graphics_ptr[0, Fiddle::SIZEOF_INTPTR_T].unpack('Q')[0]
  
  # Clear background (white)
  brush = GDI32.GetStockObject(5)  # WHITE_BRUSH
  GDI32.PatBlt(hdc, 0, 0, width, height, 0xF0_0000)  # WHITENESS
  
  # Create path
  path_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INTPTR_T)
  GDIPlus.GdipCreatePath(0, path_ptr)
  path = path_ptr[0, Fiddle::SIZEOF_INTPTR_T].unpack('Q')[0]
  
  # Create triangle points
  points_size = GDIPlus::GpPoint.size * 3
  points_ptr = Fiddle::Pointer.malloc(points_size)
  
  # Top vertex (center)
  p0 = GDIPlus::GpPoint.new(points_ptr)
  p0.x = width / 2
  p0.y = height / 4
  
  # Bottom-right vertex
  p1 = GDIPlus::GpPoint.new(points_ptr + GDIPlus::GpPoint.size)
  p1.x = width * 3 / 4
  p1.y = height * 3 / 4
  
  # Bottom-left vertex
  p2 = GDIPlus::GpPoint.new(points_ptr + GDIPlus::GpPoint.size * 2)
  p2.x = width / 4
  p2.y = height * 3 / 4
  
  # Add lines to path
  GDIPlus.GdipAddPathLine2I(path, points_ptr, 3)
  GDIPlus.GdipClosePathFigure(path)
  
  # Create path gradient brush
  brush_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INTPTR_T)
  GDIPlus.GdipCreatePathGradientFromPath(path, brush_ptr)
  brush = brush_ptr[0, Fiddle::SIZEOF_INTPTR_T].unpack('Q')[0]
  
  # Set center color (gray)
  GDIPlus.GdipSetPathGradientCenterColor(brush, 0xFF555555)
  
  # Set surrounding colors (red, green, blue)
  colors_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT * 3)
  colors_ptr[0, Fiddle::SIZEOF_INT] = [0xFFFF0000].pack('L')
  colors_ptr[Fiddle::SIZEOF_INT, Fiddle::SIZEOF_INT] = [0xFF00FF00].pack('L')
  colors_ptr[Fiddle::SIZEOF_INT * 2, Fiddle::SIZEOF_INT] = [0xFF0000FF].pack('L')
  
  count_ptr = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
  count_ptr[0, Fiddle::SIZEOF_INT] = [3].pack('I')
  
  GDIPlus.GdipSetPathGradientSurroundColorsWithCount(brush, colors_ptr, count_ptr)
  
  # Fill path with gradient
  GDIPlus.GdipFillPath(graphics, brush, path)
  
  # Cleanup
  GDIPlus.GdipDeleteBrush(brush)
  GDIPlus.GdipDeletePath(path)
  GDIPlus.GdipDeleteGraphics(graphics)
end

# Window Procedure Callback
WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_UINT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  case msg
  when User32::WM_NCCREATE
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  when User32::WM_PAINT
    ps = User32::PAINTSTRUCT.malloc
    hdc = User32.BeginPaint(hwnd, ps)
    
    # Get client area size
    rc = User32::RECT.malloc
    User32.GetClientRect(hwnd, rc)
    width  = rc.right - rc.left
    height = rc.bottom - rc.top
    
    # Draw GDI+ gradient triangle
    draw_triangle_gdiplus(hdc, width, height)
    
    User32.EndPaint(hwnd, ps)
    0
  when User32::WM_DESTROY
    User32.PostQuitMessage(0)
    0
  else
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  end
end

# Main Program
puts "=== GDI+ Triangle Demo (Ruby) ==="

# Initialize GDI+
unless gdiplus_startup
  puts "Failed to initialize GDI+"
  exit 1
end

# Get module handle
hInstance = Kernel32.GetModuleHandleA(nil)
puts "GetModuleHandleA: hInstance=#{hInstance}"

# Register window class
class_name = "RubyGDIPlusTriangle"

wc = User32::WNDCLASSEX.malloc
wc.cbSize        = User32::WNDCLASSEX.size
wc.style         = User32::CS_HREDRAW | User32::CS_VREDRAW
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
  puts "Error: RegisterClassExA failed"
  gdiplus_shutdown
  exit 1
end

# Create window
hwnd = User32.CreateWindowExA(
  0,
  class_name,
  "GDI+ Path Gradient Triangle (Ruby)",
  User32::WS_OVERLAPPEDWINDOW | User32::WS_VISIBLE,
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
  puts "Error: CreateWindowExA failed"
  gdiplus_shutdown
  exit 1
end

# Show and update window
User32.ShowWindow(hwnd, User32::SW_SHOW)
User32.UpdateWindow(hwnd)
puts "Window displayed"

# Message loop
puts "Entering message loop..."
msg = User32::MSG.malloc
while User32.GetMessageA(msg, 0, 0, 0) != 0
  User32.TranslateMessage(msg)
  User32.DispatchMessageA(msg)
end

# Cleanup
gdiplus_shutdown
puts "=== Program End ==="
