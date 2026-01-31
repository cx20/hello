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
end

# Msimg32.dll - GDI Gradient Functions
module Msimg32
  extend Fiddle::Importer
  dlload 'msimg32.dll'
  
  # GradientFill Mode Constants
  GRADIENT_FILL_TRIANGLE = 0x00000002
  
  # Type Aliases
  typealias 'BOOL',  'int'
  typealias 'DWORD', 'unsigned long'
  
  # TRIVERTEX Structure - Vertex with color information
  TRIVERTEX = struct([
    'long           x',
    'long           y',
    'unsigned short Red',
    'unsigned short Green',
    'unsigned short Blue',
    'unsigned short Alpha'
  ])
  
  # GRADIENT_TRIANGLE Structure - Triangle vertex indices
  GRADIENT_TRIANGLE = struct([
    'unsigned long Vertex1',
    'unsigned long Vertex2',
    'unsigned long Vertex3'
  ])
  
  extern 'BOOL GradientFill(uintptr_t, void*, DWORD, void*, DWORD, DWORD)'
end

# Kernel32.dll - Windows Kernel API
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  
  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'unsigned long GetLastError()'
end

# Draw gradient triangle using GradientFill API
def draw_triangle_gradient(hdc, width, height)
  # Allocate memory for 3 vertices
  vertices_size = Msimg32::TRIVERTEX.size * 3
  vertices_ptr = Fiddle::Pointer.malloc(vertices_size)
  
  # Vertex 0 - Top center (Red)
  v0 = Msimg32::TRIVERTEX.new(vertices_ptr)
  v0.x     = width / 2
  v0.y     = height / 4
  v0.Red   = 0xFFFF
  v0.Green = 0x0000
  v0.Blue  = 0x0000
  v0.Alpha = 0x0000
  
  # Vertex 1 - Bottom right (Green)
  v1 = Msimg32::TRIVERTEX.new(vertices_ptr + Msimg32::TRIVERTEX.size)
  v1.x     = width * 3 / 4
  v1.y     = height * 3 / 4
  v1.Red   = 0x0000
  v1.Green = 0xFFFF
  v1.Blue  = 0x0000
  v1.Alpha = 0x0000
  
  # Vertex 2 - Bottom left (Blue)
  v2 = Msimg32::TRIVERTEX.new(vertices_ptr + Msimg32::TRIVERTEX.size * 2)
  v2.x     = width / 4
  v2.y     = height * 3 / 4
  v2.Red   = 0x0000
  v2.Green = 0x0000
  v2.Blue  = 0xFFFF
  v2.Alpha = 0x0000
  
  # Triangle indices
  tri = Msimg32::GRADIENT_TRIANGLE.malloc
  tri.Vertex1 = 0
  tri.Vertex2 = 1
  tri.Vertex3 = 2
  
  # Call GradientFill
  result = Msimg32.GradientFill(
    hdc,
    vertices_ptr,
    3,
    tri,
    1,
    Msimg32::GRADIENT_FILL_TRIANGLE
  )
  
  puts "GradientFill result: #{result}" if result == 0
  result
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
    
    # Draw gradient triangle
    draw_triangle_gradient(hdc, width, height)
    
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
puts "=== Program Start ==="

# Get module handle
hInstance = Kernel32.GetModuleHandleA(nil)
puts "GetModuleHandleA: hInstance=#{hInstance}"

# Register window class
class_name = "RubyGradientTriangle"

wc = User32::WNDCLASSEX.malloc
wc.cbSize        = User32::WNDCLASSEX.size
wc.style         = User32::CS_HREDRAW | User32::CS_VREDRAW
wc.lpfnWndProc   = WndProc.to_i
wc.cbClsExtra    = 0
wc.cbWndExtra    = 0
wc.hInstance     = hInstance
wc.hIcon         = 0
wc.hCursor       = 0
wc.hbrBackground = 0  # No background brush (we paint everything)
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
  "GDI Gradient Triangle (Ruby)",
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
  puts "Error: CreateWindowExA failed (GetLastError=#{Kernel32.GetLastError()})"
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

puts "=== Program End ==="
