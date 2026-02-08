use strict;
use warnings;
use Win32::API;
use FFI::Platypus;
use FFI::Platypus::Memory qw(malloc memset);
use Encode qw(encode);

# ============================================================
# 64-bit only implementation
# ============================================================
my $is_64bit = 1;
my $ptr_size = 8;
my $ptr_pack = 'Q';

print "=== Perl Direct2D Triangle via COM vtable (64-bit) ===\n\n";

# ============================================================
# FFI::Platypus setup
# ============================================================
my $ffi = FFI::Platypus->new(api => 2);
$ffi->lib(undef);  # Use current process

# ============================================================
# Constants
# ============================================================
use constant {
    S_OK                => 0,
    S_FALSE             => 1,
    
    # Memory
    MEM_COMMIT              => 0x1000,
    MEM_RELEASE             => 0x8000,
    PAGE_EXECUTE_READWRITE  => 0x40,
    
    # CoInitializeEx flags
    COINIT_APARTMENTTHREADED => 0x2,
    
    # vtable indices for IUnknown
    VTBL_QueryInterface   => 0,
    VTBL_AddRef           => 1,
    VTBL_Release          => 2,
    
    # Window styles
    CS_HREDRAW          => 0x0002,
    CS_VREDRAW          => 0x0001,
    WS_OVERLAPPEDWINDOW => 0x00CF0000,
    COLOR_WINDOW        => 5,
    IDC_ARROW           => 32512,
    
    # Direct2D constants
    D2D1_FACTORY_TYPE_SINGLE_THREADED => 0,
    DXGI_FORMAT_B8G8R8A8_UNORM => 87,
    D2D1_ALPHA_MODE_IGNORE => 1,
    D2D1_RENDER_TARGET_TYPE_DEFAULT => 0,
    D2D1_FEATURE_LEVEL_DEFAULT => 0,
};

# ============================================================
# Import Windows API functions
# ============================================================
my $RtlMoveMemory_Read = Win32::API->new('kernel32', 'RtlMoveMemory', 'PNN', 'V');
my $RtlMoveMemory_Write = Win32::API->new('kernel32', 'RtlMoveMemory', 'NPN', 'V');

my $VirtualAlloc = Win32::API->new('kernel32', 'VirtualAlloc', 'NNNN', 'N');
my $VirtualFree = Win32::API->new('kernel32', 'VirtualFree', 'NNN', 'I');

my $GetModuleHandleW = Win32::API->new('kernel32', 'GetModuleHandleW', 'P', 'N');
my $LoadLibraryW = Win32::API->new('kernel32', 'LoadLibraryW', 'P', 'N');
my $GetProcAddress = Win32::API->new('kernel32', 'GetProcAddress', 'NP', 'N');
my $FreeLibrary = Win32::API->new('kernel32', 'FreeLibrary', 'N', 'I');

my $CoInitializeEx = Win32::API->new('ole32', 'CoInitializeEx', 'NN', 'I');
my $CoUninitialize = Win32::API->new('ole32', 'CoUninitialize', [], 'V');

# Use 'P' for pointer to structure - we'll pass the packed string directly
my $RegisterClassExW = Win32::API->new('user32', 'RegisterClassExW', 'P', 'I');
my $CreateWindowExW = Win32::API->new('user32', 'CreateWindowExW', 'NPPNNNNNNNNP', 'N');
my $DefWindowProcW = Win32::API->new('user32', 'DefWindowProcW', 'NNNN', 'N');
my $LoadCursorW = Win32::API->new('user32', 'LoadCursorW', 'NN', 'N');
my $GetClientRect = Win32::API->new('user32', 'GetClientRect', 'NP', 'I');
my $GetLastError = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $ShowWindow = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $UpdateWindow = Win32::API->new('user32', 'UpdateWindow', 'N', 'I');
my $GetMessageW = Win32::API->new('user32', 'GetMessageW', 'PNNN', 'I');
my $PeekMessageW = Win32::API->new('user32', 'PeekMessageW', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageW = Win32::API->new('user32', 'DispatchMessageW', 'P', 'N');
my $Sleep = Win32::API->new('kernel32', 'Sleep', 'N', 'V');

use constant {
    SW_SHOW => 5,
    SW_SHOWNORMAL => 1,
    PM_REMOVE => 0x0001,
};

# ============================================================
# Helper functions (64-bit only)
# ============================================================
sub read_ptr {
    my ($addr) = @_;
    my $buf = "\0" x 8;
    $RtlMoveMemory_Read->Call($buf, $addr, 8);
    return unpack('Q', $buf);
}

sub read_mem {
    my ($addr, $size) = @_;
    my $buf = "\0" x $size;
    $RtlMoveMemory_Read->Call($buf, $addr, $size);
    return $buf;
}

sub write_mem {
    my ($dest, $data) = @_;
    $RtlMoveMemory_Write->Call($dest, $data, length($data));
}

sub encode_utf16 {
    my ($str) = @_;
    # Use Encode module for proper UTF-16LE encoding
    my $utf16 = encode('UTF-16LE', $str);
    $utf16 .= "\0\0";  # Null terminator
    return $utf16;
}

sub guid_from_string {
    my ($s) = @_;
    $s =~ s/[{}]//g;
    my @p = split /-/, $s;
    return pack('L S S', hex($p[0]), hex($p[1]), hex($p[2])) . pack('H*', $p[3] . $p[4]);
}

# Get pointer address of a Perl scalar
sub get_ptr_of {
    my ($ref) = @_;
    # unpack 'Q' to get the address from a reference
    return unpack('Q', pack('P', $$ref));
}

# ============================================================
# Thunk memory management
# ============================================================
my $thunk_mem;
my $thunk_size = 1024;

sub init_thunk_memory {
    $thunk_mem = $VirtualAlloc->Call(0, $thunk_size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    die "VirtualAlloc for thunk failed" unless $thunk_mem;
}

sub free_thunk_memory {
    $VirtualFree->Call($thunk_mem, 0, MEM_RELEASE) if $thunk_mem;
}

sub call_thunk {
    my ($code) = @_;
    write_mem($thunk_mem, $code);
    my $func = $ffi->function($thunk_mem => [] => 'uint32');
    return $func->call();
}

# ============================================================
# COM vtable method calls via inline assembly stubs
# ============================================================

# Call Release (ULONG this) - x64 only
sub call_release {
    my ($func_addr, $this) = @_;
    
    my $code;
    $code = pack('H*', '4883EC28');                      # sub rsp, 0x28
    $code .= pack('H*', '48B9') . pack('Q', $this);      # mov rcx, this
    $code .= pack('H*', '48B8') . pack('Q', $func_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                         # call rax
    $code .= pack('H*', '4883C428');                     # add rsp, 0x28
    $code .= pack('H*', 'C3');                           # ret
    
    return call_thunk($code);
}

# ============================================================
# Direct2D initialization
# ============================================================
my $work_mem;
my $work_offset;
my $factory;
my $render_target;
my $brush;
my $hwnd;

sub alloc_work {
    my ($size) = @_;
    my $ptr = $work_mem + $work_offset;
    $work_offset += $size;
    $work_offset = ($work_offset + 7) & ~7;
    return $ptr;
}

sub init_d2d {
    # Load d2d1.dll
    my $d2d1_dll_str = encode_utf16("d2d1.dll");
    my $hD2D1 = $LoadLibraryW->Call($d2d1_dll_str);
    die "LoadLibraryW(d2d1.dll) failed\n" unless $hD2D1;
    print "d2d1.dll: ", sprintf("0x%X", $hD2D1), "\n";
    
    # Get D2D1CreateFactory function
    my $create_factory_name = "D2D1CreateFactory\0";
    my $D2D1CreateFactory = $GetProcAddress->Call($hD2D1, $create_factory_name);
    die "GetProcAddress(D2D1CreateFactory) failed\n" unless $D2D1CreateFactory;
    print "D2D1CreateFactory: ", sprintf("0x%X", $D2D1CreateFactory), "\n";
    
    # Call D2D1CreateFactory via thunk (x64)
    my $code;
    my $factory_ptr_addr = alloc_work(8);
    write_mem($factory_ptr_addr, "\0" x 8);
    
    my $iid_factory = guid_from_string("{06152247-6f50-465a-9245-118bfd3b6007}");
    my $iid_factory_addr = alloc_work(16);
    write_mem($iid_factory_addr, $iid_factory);
    
    # x64 calling convention
    $code = pack('H*', '4883EC28');                                # sub rsp, 0x28
    $code .= pack('H*', '48B9') . pack('Q', D2D1_FACTORY_TYPE_SINGLE_THREADED); # mov rcx, 0
    $code .= pack('H*', '48BA') . pack('Q', $iid_factory_addr);   # mov rdx, iid
    $code .= pack('H*', '49B80000000000000000');                  # mov r8, 0 (options)
    $code .= pack('H*', '49B9') . pack('Q', $factory_ptr_addr);   # mov r9, &factory
    $code .= pack('H*', '48B8') . pack('Q', $D2D1CreateFactory);  # mov rax, func
    $code .= pack('H*', 'FFD0');                                  # call rax
    $code .= pack('H*', '4883C428');                              # add rsp, 0x28
    $code .= pack('H*', 'C3');                                    # ret
    
    my $hr = call_thunk($code);
    die "D2D1CreateFactory failed\n" if $hr != S_OK;
    
    $factory = unpack('Q', read_mem($factory_ptr_addr, 8));
    print "Factory: ", sprintf("0x%X", $factory), "\n";
    
    # Get factory vtable
    my $factory_vtbl = read_ptr($factory);
    print "Factory vtable: ", sprintf("0x%X", $factory_vtbl), "\n";
    
    # CreateHwndRenderTarget (vtable #14) - x64
    my $create_hwnd_rt_addr = read_ptr($factory_vtbl + 14 * 8);
    print "CreateHwndRenderTarget: ", sprintf("0x%X", $create_hwnd_rt_addr), "\n";
    
    # Get client rect
    my $rc = "\0" x 16;
    $GetClientRect->Call($hwnd, $rc);
    my ($left, $top, $right, $bottom) = unpack('l l l l', $rc);
    my $width = $right - $left;
    my $height = $bottom - $top;
    print "Client rect: $width x $height\n";
    
    # Create render target properties
    my $rtProps_addr = alloc_work(32);
    # D2D1_RENDER_TARGET_PROPERTIES: type, pixelFormat(format, alphaMode), dpiX, dpiY, usage, minLevel
    my $pixel_format = pack('L L', DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_IGNORE);
    my $rtProps = pack('L', D2D1_RENDER_TARGET_TYPE_DEFAULT) . $pixel_format . 
                  pack('f f L L', 0.0, 0.0, 0, D2D1_FEATURE_LEVEL_DEFAULT);
    write_mem($rtProps_addr, $rtProps);
    
    # Create hwnd render target properties
    my $hwndProps_addr = alloc_work(24);
    my $hwndProps = pack('Q L L L', $hwnd, $width, $height, 0);
    write_mem($hwndProps_addr, $hwndProps);
    
    # Allocate render target pointer
    my $rt_ptr_addr = alloc_work(8);
    write_mem($rt_ptr_addr, "\0" x 8);
    
    # Call CreateHwndRenderTarget via thunk (x64)
    $code = pack('H*', '4883EC38');                              # sub rsp, 0x38
    $code .= pack('H*', '48B9') . pack('Q', $factory);           # mov rcx, factory
    $code .= pack('H*', '48BA') . pack('Q', $rtProps_addr);      # mov rdx, rtProps
    $code .= pack('H*', '49B8') . pack('Q', $hwndProps_addr);    # mov r8, hwndProps
    $code .= pack('H*', '49B9') . pack('Q', $rt_ptr_addr);       # mov r9, &rt
    $code .= pack('H*', '48B8') . pack('Q', $create_hwnd_rt_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                                 # call rax
    $code .= pack('H*', '4883C438');                             # add rsp, 0x38
    $code .= pack('H*', 'C3');                                   # ret
    
    $hr = call_thunk($code);
    die "CreateHwndRenderTarget failed: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n" if $hr != S_OK;
    
    $render_target = unpack('Q', read_mem($rt_ptr_addr, 8));
    print "Render target: ", sprintf("0x%X", $render_target), "\n";
    
    # Get render target vtable
    my $rt_vtbl = read_ptr($render_target);
    print "Render target vtable: ", sprintf("0x%X", $rt_vtbl), "\n";
    
    # CreateSolidColorBrush (vtable #8) - x64
    my $create_brush_addr = read_ptr($rt_vtbl + 8 * 8);
    print "CreateSolidColorBrush: ", sprintf("0x%X", $create_brush_addr), "\n";
    
    # Create blue color (r, g, b, a)
    my $color_addr = alloc_work(16);
    write_mem($color_addr, pack('f f f f', 0.0, 0.0, 1.0, 1.0));  # Blue
    
    my $brush_ptr_addr = alloc_work(8);
    write_mem($brush_ptr_addr, "\0" x 8);
    
    # Call CreateSolidColorBrush via thunk (x64)
    $code = pack('H*', '4883EC28');                           # sub rsp, 0x28
    $code .= pack('H*', '48B9') . pack('Q', $render_target);  # mov rcx, rt
    $code .= pack('H*', '48BA') . pack('Q', $color_addr);     # mov rdx, color
    $code .= pack('H*', '49B80000000000000000');              # mov r8, 0 (brushProps)
    $code .= pack('H*', '49B9') . pack('Q', $brush_ptr_addr); # mov r9, &brush
    $code .= pack('H*', '48B8') . pack('Q', $create_brush_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                              # call rax
    $code .= pack('H*', '4883C428');                          # add rsp, 0x28
    $code .= pack('H*', 'C3');                                # ret
    
    $hr = call_thunk($code);
    die "CreateSolidColorBrush failed: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n" if $hr != S_OK;
    
    $brush = unpack('Q', read_mem($brush_ptr_addr, 8));
    print "Brush: ", sprintf("0x%X", $brush), "\n";
    
    return $work_mem;
}

# ============================================================
# Drawing
# ============================================================
sub draw_triangle {
    return unless $render_target;
    
    my $rt_vtbl = read_ptr($render_target);
    
    # BeginDraw (vtable #48) - x64
    my $begin_draw_addr = read_ptr($rt_vtbl + 48 * 8);
    
    my $code = pack('H*', '4883EC28');                       # sub rsp, 0x28
    $code .= pack('H*', '48B9') . pack('Q', $render_target); # mov rcx, rt
    $code .= pack('H*', '48B8') . pack('Q', $begin_draw_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                          # call rax
    $code .= pack('H*', '4883C428');                      # add rsp, 0x28
    $code .= pack('H*', 'C3');                            # ret
    call_thunk($code);
    print "  BeginDraw called\n";
    
    # Clear (vtable #47) - x64
    my $clear_addr = read_ptr($rt_vtbl + 47 * 8);
    
    # Allocate work memory for colors and points
    my $draw_work_mem = $VirtualAlloc->Call(0, 4096, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    my $color_addr = $draw_work_mem;
    write_mem($color_addr, pack('f f f f', 1.0, 1.0, 1.0, 1.0));  # White
    
    $code = pack('H*', '4883EC28');                       # sub rsp, 0x28
    $code .= pack('H*', '48B9') . pack('Q', $render_target); # mov rcx, rt
    $code .= pack('H*', '48BA') . pack('Q', $color_addr); # mov rdx, color
    $code .= pack('H*', '48B8') . pack('Q', $clear_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                          # call rax
    $code .= pack('H*', '4883C428');                      # add rsp, 0x28
    $code .= pack('H*', 'C3');                            # ret
    call_thunk($code);
    print "  Clear called\n";
    
    # DrawLine (vtable #15) - Draw triangle using 3 lines (x64)
    # void DrawLine(D2D1_POINT_2F point0, D2D1_POINT_2F point1, 
    #               ID2D1Brush *brush, FLOAT strokeWidth, ID2D1StrokeStyle *strokeStyle)
    # D2D1_POINT_2F is 8 bytes (two floats) - passed by VALUE in register
    my $draw_line_addr = read_ptr($rt_vtbl + 15 * 8);
    
    # Triangle points as 8-byte values (two floats packed together)
    my $p1 = pack('f f', 320.0, 120.0);  # Top
    my $p2 = pack('f f', 480.0, 360.0);  # Bottom right
    my $p3 = pack('f f', 160.0, 360.0);  # Bottom left
    
    # strokeWidth as float (2.0)
    my $stroke_width_addr = $draw_work_mem + 64;
    write_mem($stroke_width_addr, pack('f', 2.0));
    
    # Line 1: p1 to p2
    # rcx = this, rdx = point0 (value), r8 = point1 (value), r9 = brush
    # [rsp+0x20] = strokeWidth (float), [rsp+0x28] = strokeStyle (NULL)
    $code = pack('H*', '4883EC48');                       # sub rsp, 0x48
    $code .= pack('H*', '48B9') . pack('Q', $render_target); # mov rcx, rt
    $code .= pack('H*', '48BA') . $p1;                    # mov rdx, p1 (value)
    $code .= pack('H*', '49B8') . $p2;                    # mov r8, p2 (value)
    $code .= pack('H*', '49B9') . pack('Q', $brush);      # mov r9, brush
    # Store strokeWidth (2.0f) at [rsp+0x20]
    $code .= pack('H*', 'C744242000000040');              # mov dword [rsp+0x20], 0x40000000 (2.0f)
    $code .= pack('H*', '48C744242800000000');            # mov qword [rsp+0x28], 0 (NULL)
    $code .= pack('H*', '48B8') . pack('Q', $draw_line_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                          # call rax
    $code .= pack('H*', '4883C448');                      # add rsp, 0x48
    $code .= pack('H*', 'C3');                            # ret
    call_thunk($code);
    print "  DrawLine 1 called\n";
    
    # Line 2: p2 to p3
    $code = pack('H*', '4883EC48');                       # sub rsp, 0x48
    $code .= pack('H*', '48B9') . pack('Q', $render_target); # mov rcx, rt
    $code .= pack('H*', '48BA') . $p2;                    # mov rdx, p2 (value)
    $code .= pack('H*', '49B8') . $p3;                    # mov r8, p3 (value)
    $code .= pack('H*', '49B9') . pack('Q', $brush);      # mov r9, brush
    $code .= pack('H*', 'C744242000000040');              # mov dword [rsp+0x20], 0x40000000 (2.0f)
    $code .= pack('H*', '48C744242800000000');            # mov qword [rsp+0x28], 0 (NULL)
    $code .= pack('H*', '48B8') . pack('Q', $draw_line_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                          # call rax
    $code .= pack('H*', '4883C448');                      # add rsp, 0x48
    $code .= pack('H*', 'C3');                            # ret
    call_thunk($code);
    print "  DrawLine 2 called\n";
    
    # Line 3: p3 to p1
    $code = pack('H*', '4883EC48');                       # sub rsp, 0x48
    $code .= pack('H*', '48B9') . pack('Q', $render_target); # mov rcx, rt
    $code .= pack('H*', '48BA') . $p3;                    # mov rdx, p3 (value)
    $code .= pack('H*', '49B8') . $p1;                    # mov r8, p1 (value)
    $code .= pack('H*', '49B9') . pack('Q', $brush);      # mov r9, brush
    $code .= pack('H*', 'C744242000000040');              # mov dword [rsp+0x20], 0x40000000 (2.0f)
    $code .= pack('H*', '48C744242800000000');            # mov qword [rsp+0x28], 0 (NULL)
    $code .= pack('H*', '48B8') . pack('Q', $draw_line_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                          # call rax
    $code .= pack('H*', '4883C448');                      # add rsp, 0x48
    $code .= pack('H*', 'C3');                            # ret
    call_thunk($code);
    print "  DrawLine 3 called\n";
    
    # EndDraw (vtable #49) - x64
    my $end_draw_addr = read_ptr($rt_vtbl + 49 * 8);
    
    $code = pack('H*', '4883EC28');                       # sub rsp, 0x28
    $code .= pack('H*', '48B9') . pack('Q', $render_target); # mov rcx, rt
    $code .= pack('H*', '48BA0000000000000000');          # mov rdx, 0 (tag1)
    $code .= pack('H*', '49B80000000000000000');          # mov r8, 0 (tag2)
    $code .= pack('H*', '48B8') . pack('Q', $end_draw_addr); # mov rax, func
    $code .= pack('H*', 'FFD0');                          # call rax
    $code .= pack('H*', '4883C428');                      # add rsp, 0x28
    $code .= pack('H*', 'C3');                            # ret
    call_thunk($code);
    print "  EndDraw called\n";
    
    $VirtualFree->Call($draw_work_mem, 0, MEM_RELEASE);
}

# ============================================================
# Note: This uses DefWindowProcW directly as window procedure
# ============================================================

# ============================================================
# Main
# ============================================================
print "Initializing COM...\n";

my $hr = $CoInitializeEx->Call(0, COINIT_APARTMENTTHREADED);
print "CoInitializeEx: ", sprintf("0x%08X", $hr & 0xFFFFFFFF), "\n";

if ($hr != S_OK && $hr != S_FALSE && ($hr & 0xFFFFFFFF) != 0x80010106) {
    die "CoInitializeEx failed\n";
}
print "COM initialized successfully\n";

init_thunk_memory();
print "Thunk memory: ", sprintf("0x%X", $thunk_mem), "\n";

# Initialize work memory for structures
my $work_mem_size = 8192;
$work_mem = $VirtualAlloc->Call(0, $work_mem_size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
die "VirtualAlloc for work_mem failed" unless $work_mem;
$work_offset = 0;
print "Work memory: ", sprintf("0x%X", $work_mem), "\n";

eval {
    print "\n--- Direct2D COM vtable Demonstration ---\n";
    print "This demonstrates calling Direct2D methods via vtable indices.\n\n";
    
    # Create a simple window for Direct2D render target
    my $hinstance = $GetModuleHandleW->Call(0);
    my $hcursor = $LoadCursorW->Call(0, IDC_ARROW);
    
    # Get DefWindowProcW address to use directly as window procedure
    my $user32_str = encode_utf16("user32.dll");
    my $user32 = $LoadLibraryW->Call($user32_str);
    my $defproc_addr = $GetProcAddress->Call($user32, "DefWindowProcW\0");
    print "DefWindowProcW address: ", sprintf("0x%X", $defproc_addr), "\n";
    
    # Create window class with DefWindowProcW as procedure
    my $class_name = encode_utf16("PerlD2DClass" . $$);  # Add PID for uniqueness
    my $class_name_addr = alloc_work(length($class_name));
    write_mem($class_name_addr, $class_name);
    print "Class name address: ", sprintf("0x%X", $class_name_addr), "\n";
    
    # Build WNDCLASSEXW structure (80 bytes for x64)
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80,                        # cbSize = 80 bytes
        CS_HREDRAW | CS_VREDRAW,   # style
        $defproc_addr,             # lpfnWndProc (DefWindowProcW)
        0,                         # cbClsExtra
        0,                         # cbWndExtra
        $hinstance,                # hInstance
        0,                         # hIcon
        $hcursor,                  # hCursor
        COLOR_WINDOW + 1,          # hbrBackground
        0,                         # lpszMenuName
        $class_name_addr,          # lpszClassName
        0                          # hIconSm
    );
    
    my $wndclass_addr = alloc_work(80);
    write_mem($wndclass_addr, $wndclass);
    
    print "WNDCLASSEX size: ", length($wndclass), " bytes\n";
    print "hInstance: ", sprintf("0x%X", $hinstance), "\n";
    print "hCursor: ", sprintf("0x%X", $hcursor), "\n";
    
    # Pass the packed structure directly to RegisterClassExW
    # Win32::API with 'P' type expects a Perl string
    my $class_atom = $RegisterClassExW->Call($wndclass);
    unless ($class_atom) {
        my $err = $GetLastError->Call();
        die sprintf("RegisterClassExW failed: 0x%08X\n", $err);
    }
    print "Window class registered, atom: $class_atom\n";
    
    # Create a simple window
    my $window_title = encode_utf16("Direct2D Perl Demo");
    
    $hwnd = $CreateWindowExW->Call(
        0,                         # dwExStyle
        $class_name,               # lpClassName (UTF-16 string)
        $window_title,             # lpWindowName (UTF-16 string)
        WS_OVERLAPPEDWINDOW,       # dwStyle
        100, 100,                  # x, y
        640, 480,                  # width, height
        0, 0,                      # hWndParent, hMenu
        $hinstance,                # hInstance
        0                          # lpParam
    );
    
    unless ($hwnd) {
        my $err = $GetLastError->Call();
        die sprintf("CreateWindowExW failed: 0x%08X\n", $err);
    }
    print "Window created: ", sprintf("0x%X", $hwnd), "\n";
    
    # Show the window
    $ShowWindow->Call($hwnd, SW_SHOWNORMAL);
    $UpdateWindow->Call($hwnd);
    print "Window shown\n\n";
    
    # Initialize Direct2D with COM vtable calls
    print "Initializing Direct2D via vtable...\n";
    init_d2d();
    
    print "\n--- Direct2D Triangle Drawing (vtable demonstration) ---\n";
    print "The following vtable calls would render a triangle:\n\n";
    
    print "1. RenderTarget->BeginDraw() [vtable[48]]\n";
    print "2. RenderTarget->Clear(white) [vtable[47]]\n";
    print "3. RenderTarget->DrawLine(p1, p2, blueBrush) [vtable[15]]\n";
    print "4. RenderTarget->DrawLine(p2, p3, blueBrush) [vtable[15]]\n";
    print "5. RenderTarget->DrawLine(p3, p1, blueBrush) [vtable[15]]\n";
    print "6. RenderTarget->EndDraw() [vtable[49]]\n\n";
    
    print "Triangle points:\n";
    print "  P1: (320, 120)\n";
    print "  P2: (480, 360)\n";
    print "  P3: (160, 360)\n\n";
    
    print "All COM methods are called through vtable function pointers.\n";
    print "Assembly thunks handle x64 calling conventions.\n\n";
    
    # Demonstrate one draw call
    print "Executing draw sequence...\n";
    draw_triangle();
    print "Draw sequence completed successfully.\n\n";
    
    print "Window is now visible. Running message loop for 5 seconds...\n";
    print "Press Ctrl+C to exit early.\n\n";
    
    # Simple message loop with timeout
    my $msg = "\0" x 48;  # MSG structure (48 bytes on x64)
    my $start_time = time();
    my $duration = 5;  # seconds
    
    while (time() - $start_time < $duration) {
        # Process all pending messages
        while ($PeekMessageW->Call($msg, 0, 0, 0, PM_REMOVE)) {
            $TranslateMessage->Call($msg);
            $DispatchMessageW->Call($msg);
        }
        
        # Redraw
        draw_triangle();
        $Sleep->Call(16);  # ~60 FPS
    }
    
    print "Message loop finished.\n";
};

if ($@) {
    print "Error: $@\n";
}

# Final cleanup
free_thunk_memory();
$CoUninitialize->Call();

print "Done.\n";