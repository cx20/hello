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
  CW_USEDEFAULT = -2147483648  # 0x80000000 as signed 32-bit integer
  
  # Window Message Constants
  WM_DESTROY  = 0x0002
  WM_PAINT    = 0x000F
  WM_NCCREATE = 0x0081
  
  # ShowWindow Constants
  SW_SHOW = 5
  
  # Type Aliases for Windows API types
  typealias 'UINT',    'unsigned int'
  typealias 'DWORD',   'unsigned long'
  typealias 'LONG',    'long'
  typealias 'USHORT',  'unsigned short'
  typealias 'UINTPTR', 'uintptr_t'
  
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
end

# Gdi32.dll - Graphics Device Interface API
module Gdi32
  extend Fiddle::Importer
  dlload 'gdi32.dll'
  
  extern 'int TextOutA(uintptr_t, int, int, const char*, int)'
end

# Kernel32.dll - Windows Kernel API
module Kernel32
  extend Fiddle::Importer
  dlload 'kernel32.dll'
  
  extern 'uintptr_t GetModuleHandleA(const char*)'
  extern 'unsigned long GetLastError()'
end

# Window Procedure Callback
# Handles window messages from the Windows message queue
WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_UINT, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  case msg
  when User32::WM_NCCREATE
    # Must return result from DefWindowProcA for window creation to succeed
    User32.DefWindowProcA(hwnd, msg, wparam, lparam)
  when User32::WM_PAINT
    ps = User32::PAINTSTRUCT.malloc
    hdc = User32.BeginPaint(hwnd, ps)
    message = "Hello, Win32 GUI(Ruby) World!"
    Gdi32.TextOutA(hdc, 0, 0, message, message.length)
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
class_name = "RubyWin32Window"

wc = User32::WNDCLASSEX.malloc
wc.cbSize        = User32::WNDCLASSEX.size
wc.style         = User32::CS_HREDRAW | User32::CS_VREDRAW
wc.lpfnWndProc   = WndProc.to_i
wc.cbClsExtra    = 0
wc.cbWndExtra    = 0
wc.hInstance     = hInstance
wc.hIcon         = 0
wc.hCursor       = 0
wc.hbrBackground = 6  # COLOR_WINDOW + 1
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
  "Hello, World!",
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
