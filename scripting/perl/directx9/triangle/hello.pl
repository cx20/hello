use strict;
use warnings;
use Win32::API;
use FFI::Platypus;
use Encode qw(encode);

# ============================================================
# 64-bit only implementation
# ============================================================
print "=== Perl DirectX9 Triangle via COM vtable (64-bit) ===\n\n";

# ============================================================
# FFI::Platypus setup
# ============================================================
my $ffi = FFI::Platypus->new(api => 2);
$ffi->lib(undef);

# ============================================================
# Constants
# ============================================================
use constant {
    S_OK => 0,
    
    # Memory
    MEM_COMMIT             => 0x1000,
    MEM_RELEASE            => 0x8000,
    PAGE_EXECUTE_READWRITE => 0x40,
    
    # Window styles
    CS_HREDRAW          => 0x0002,
    CS_VREDRAW          => 0x0001,
    WS_OVERLAPPEDWINDOW => 0x00CF0000,
    COLOR_WINDOW        => 5,
    IDC_ARROW           => 32512,
    SW_SHOWNORMAL       => 1,
    PM_REMOVE           => 0x0001,
    
    # DirectX 9 constants
    D3D_SDK_VERSION                   => 32,
    D3DADAPTER_DEFAULT                => 0,
    D3DDEVTYPE_HAL                    => 1,
    D3DCREATE_SOFTWARE_VERTEXPROCESSING => 0x00000020,
    D3DFMT_UNKNOWN                    => 0,
    D3DSWAPEFFECT_DISCARD             => 1,
    D3DPOOL_DEFAULT                   => 0,
    D3DCLEAR_TARGET                   => 0x00000001,
    D3DPT_TRIANGLELIST                => 4,
    
    # FVF flags
    D3DFVF_XYZRHW  => 0x004,
    D3DFVF_DIFFUSE => 0x040,
};

use constant D3DFVF_VERTEX => D3DFVF_XYZRHW | D3DFVF_DIFFUSE;

# D3D9 COM vtable indices
use constant {
    IDirect3D9_CreateDevice => 16,
    
    IDirect3DDevice9_Present            => 17,
    IDirect3DDevice9_CreateVertexBuffer => 26,
    IDirect3DDevice9_BeginScene         => 41,
    IDirect3DDevice9_EndScene           => 42,
    IDirect3DDevice9_Clear              => 43,
    IDirect3DDevice9_DrawPrimitive      => 81,
    IDirect3DDevice9_SetFVF             => 89,
    IDirect3DDevice9_SetStreamSource    => 100,
    
    IDirect3DVertexBuffer9_Lock   => 11,
    IDirect3DVertexBuffer9_Unlock => 12,
    
    IUnknown_Release => 2,
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

# IMPORTANT: RegisterClassExW takes 'P' (pointer to structure as Perl string)
my $RegisterClassExW = Win32::API->new('user32', 'RegisterClassExW', 'P', 'I');
# IMPORTANT: CreateWindowExW - 12 parameters total
my $CreateWindowExW = Win32::API->new('user32', 'CreateWindowExW', 'NPPNNNNNNNNP', 'N');
my $LoadCursorW = Win32::API->new('user32', 'LoadCursorW', 'NN', 'N');
my $GetLastError = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $ShowWindow = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $UpdateWindow = Win32::API->new('user32', 'UpdateWindow', 'N', 'I');
my $PeekMessageW = Win32::API->new('user32', 'PeekMessageW', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageW = Win32::API->new('user32', 'DispatchMessageW', 'P', 'N');
my $Sleep = Win32::API->new('kernel32', 'Sleep', 'N', 'V');

# ============================================================
# Helper functions
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
    my $utf16 = encode('UTF-16LE', $str);
    $utf16 .= "\0\0";
    return $utf16;
}

sub D3DCOLOR_XRGB {
    my ($r, $g, $b) = @_;
    return 0xFF000000 | ($r << 16) | ($g << 8) | $b;
}

# ============================================================
# Thunk memory management
# ============================================================
my $thunk_mem;
my $thunk_size = 2048;

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

sub call_thunk_ptr {
    my ($code) = @_;
    write_mem($thunk_mem, $code);
    my $func = $ffi->function($thunk_mem => [] => 'uint64');
    return $func->call();
}

# ============================================================
# Work memory management
# ============================================================
my $work_mem;
my $work_offset;

sub alloc_work {
    my ($size) = @_;
    my $ptr = $work_mem + $work_offset;
    $work_offset += $size;
    $work_offset = ($work_offset + 15) & ~15;
    return $ptr;
}

# ============================================================
# Global D3D objects
# ============================================================
my $hwnd;
my $g_pD3D;
my $g_pd3dDevice;
my $g_pVB;

# ============================================================
# COM vtable method callers
# ============================================================
sub com_call_0 {
    my ($obj, $vtbl_index) = @_;
    my $vtbl = read_ptr($obj);
    my $func_addr = read_ptr($vtbl + $vtbl_index * 8);
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $obj);
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    
    return call_thunk($code);
}

sub com_call_1 {
    my ($obj, $vtbl_index, $arg1) = @_;
    my $vtbl = read_ptr($obj);
    my $func_addr = read_ptr($vtbl + $vtbl_index * 8);
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $obj);
    $code .= pack('H*', '48BA') . pack('Q', $arg1);
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    
    return call_thunk($code);
}

sub com_call_3 {
    my ($obj, $vtbl_index, $arg1, $arg2, $arg3) = @_;
    my $vtbl = read_ptr($obj);
    my $func_addr = read_ptr($vtbl + $vtbl_index * 8);
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $obj);
    $code .= pack('H*', '48BA') . pack('Q', $arg1);
    $code .= pack('H*', '49B8') . pack('Q', $arg2);
    $code .= pack('H*', '49B9') . pack('Q', $arg3);
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    
    return call_thunk($code);
}

sub com_call_4 {
    my ($obj, $vtbl_index, $arg1, $arg2, $arg3, $arg4) = @_;
    my $vtbl = read_ptr($obj);
    my $func_addr = read_ptr($vtbl + $vtbl_index * 8);
    
    my $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $obj);
    $code .= pack('H*', '48BA') . pack('Q', $arg1);
    $code .= pack('H*', '49B8') . pack('Q', $arg2);
    $code .= pack('H*', '49B9') . pack('Q', $arg3);
    $code .= pack('H*', '48B8') . pack('Q', $arg4);
    $code .= pack('H*', '4889442420');
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    return call_thunk($code);
}

# ============================================================
# D3D9 initialization
# ============================================================
sub init_d3d {
    my $d3d9_dll_str = encode_utf16("d3d9.dll");
    my $hD3D9 = $LoadLibraryW->Call($d3d9_dll_str);
    die "LoadLibraryW(d3d9.dll) failed\n" unless $hD3D9;
    print "d3d9.dll: ", sprintf("0x%X", $hD3D9), "\n";
    
    my $Direct3DCreate9 = $GetProcAddress->Call($hD3D9, "Direct3DCreate9\0");
    die "GetProcAddress(Direct3DCreate9) failed\n" unless $Direct3DCreate9;
    print "Direct3DCreate9: ", sprintf("0x%X", $Direct3DCreate9), "\n";
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48C7C1') . pack('V', D3D_SDK_VERSION);
    $code .= pack('H*', '48B8') . pack('Q', $Direct3DCreate9);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    
    $g_pD3D = call_thunk_ptr($code);
    die "Direct3DCreate9 failed\n" unless $g_pD3D;
    print "IDirect3D9: ", sprintf("0x%X", $g_pD3D), "\n";
    
    my $d3dpp_addr = alloc_work(64);
    # D3DPRESENT_PARAMETERS structure (64 bytes on 64-bit)
    # Layout with alignment:
    #   Offset 0:  BackBufferWidth (4)
    #   Offset 4:  BackBufferHeight (4)
    #   Offset 8:  BackBufferFormat (4)
    #   Offset 12: BackBufferCount (4)
    #   Offset 16: MultiSampleType (4)
    #   Offset 20: MultiSampleQuality (4)
    #   Offset 24: SwapEffect (4)
    #   Offset 28: padding (4) - for HWND alignment
    #   Offset 32: hDeviceWindow (8)
    #   Offset 40: Windowed (4)
    #   Offset 44: EnableAutoDepthStencil (4)
    #   Offset 48: AutoDepthStencilFormat (4)
    #   Offset 52: Flags (4)
    #   Offset 56: FullScreen_RefreshRateInHz (4)
    #   Offset 60: PresentationInterval (4)
    my $d3dpp = pack('L7 x4 Q L6',
        0,                      # BackBufferWidth
        0,                      # BackBufferHeight
        D3DFMT_UNKNOWN,         # BackBufferFormat
        0,                      # BackBufferCount
        0,                      # MultiSampleType
        0,                      # MultiSampleQuality
        D3DSWAPEFFECT_DISCARD,  # SwapEffect
        # x4 = 4 bytes padding for HWND alignment
        $hwnd,                  # hDeviceWindow (8 bytes on 64-bit)
        1,                      # Windowed (TRUE)
        0,                      # EnableAutoDepthStencil
        0,                      # AutoDepthStencilFormat
        0,                      # Flags
        0,                      # FullScreen_RefreshRateInHz
        0                       # PresentationInterval
    );
    print "D3DPRESENT_PARAMETERS size: ", length($d3dpp), " bytes\n";
    write_mem($d3dpp_addr, $d3dpp);
    
    my $device_ptr_addr = alloc_work(8);
    write_mem($device_ptr_addr, "\0" x 8);
    
    my $vtbl = read_ptr($g_pD3D);
    my $create_device_addr = read_ptr($vtbl + IDirect3D9_CreateDevice * 8);
    
    $code = pack('H*', '4883EC48');
    $code .= pack('H*', '48B9') . pack('Q', $g_pD3D);
    $code .= pack('H*', '48C7C2') . pack('V', D3DADAPTER_DEFAULT);
    $code .= pack('H*', '49C7C0') . pack('V', D3DDEVTYPE_HAL);
    $code .= pack('H*', '49B9') . pack('Q', $hwnd);
    $code .= pack('H*', 'C7442420') . pack('V', D3DCREATE_SOFTWARE_VERTEXPROCESSING);
    $code .= pack('H*', '48B8') . pack('Q', $d3dpp_addr);
    $code .= pack('H*', '4889442428');
    $code .= pack('H*', '48B8') . pack('Q', $device_ptr_addr);
    $code .= pack('H*', '4889442430');
    $code .= pack('H*', '48B8') . pack('Q', $create_device_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C448');
    $code .= pack('H*', 'C3');
    
    my $hr = call_thunk($code);
    die sprintf("CreateDevice failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_pd3dDevice = read_ptr($device_ptr_addr);
    print "IDirect3DDevice9: ", sprintf("0x%X", $g_pd3dDevice), "\n";
}

sub init_vb {
    my $vertex_size = 20;
    my $num_vertices = 3;
    my $vb_size = $vertex_size * $num_vertices;
    
    my @vertices = (
        [320.0, 100.0, 0.0, 1.0, D3DCOLOR_XRGB(255, 0, 0)],
        [520.0, 380.0, 0.0, 1.0, D3DCOLOR_XRGB(0, 255, 0)],
        [120.0, 380.0, 0.0, 1.0, D3DCOLOR_XRGB(0, 0, 255)],
    );
    
    my $vertex_data = '';
    for my $v (@vertices) {
        $vertex_data .= pack('f f f f L', @$v);
    }
    
    my $vb_ptr_addr = alloc_work(8);
    write_mem($vb_ptr_addr, "\0" x 8);
    
    my $vtbl = read_ptr($g_pd3dDevice);
    my $create_vb_addr = read_ptr($vtbl + IDirect3DDevice9_CreateVertexBuffer * 8);
    
    my $code = pack('H*', '4883EC48');
    $code .= pack('H*', '48B9') . pack('Q', $g_pd3dDevice);
    $code .= pack('H*', '48C7C2') . pack('V', $vb_size);
    $code .= pack('H*', '49C7C0') . pack('V', 0);
    $code .= pack('H*', '49C7C1') . pack('V', D3DFVF_VERTEX);
    $code .= pack('H*', 'C7442420') . pack('V', D3DPOOL_DEFAULT);
    $code .= pack('H*', '48B8') . pack('Q', $vb_ptr_addr);
    $code .= pack('H*', '4889442428');
    $code .= pack('H*', '48C744243000000000');
    $code .= pack('H*', '48B8') . pack('Q', $create_vb_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C448');
    $code .= pack('H*', 'C3');
    
    my $hr = call_thunk($code);
    die sprintf("CreateVertexBuffer failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_pVB = read_ptr($vb_ptr_addr);
    print "IDirect3DVertexBuffer9: ", sprintf("0x%X", $g_pVB), "\n";
    
    my $pdata_addr = alloc_work(8);
    write_mem($pdata_addr, "\0" x 8);
    
    $vtbl = read_ptr($g_pVB);
    my $lock_addr = read_ptr($vtbl + IDirect3DVertexBuffer9_Lock * 8);
    
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_pVB);
    $code .= pack('H*', '48C7C200000000');
    $code .= pack('H*', '49C7C0') . pack('V', $vb_size);
    $code .= pack('H*', '49B9') . pack('Q', $pdata_addr);
    $code .= pack('H*', 'C744242000000000');
    $code .= pack('H*', '48B8') . pack('Q', $lock_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    die sprintf("Lock failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    my $pdata = read_ptr($pdata_addr);
    write_mem($pdata, $vertex_data);
    
    $hr = com_call_0($g_pVB, IDirect3DVertexBuffer9_Unlock);
    die sprintf("Unlock failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    print "Vertex buffer initialized\n";
}

sub render {
    return unless $g_pd3dDevice;
    
    my $vtbl = read_ptr($g_pd3dDevice);
    my $clear_addr = read_ptr($vtbl + IDirect3DDevice9_Clear * 8);
    my $clear_color = D3DCOLOR_XRGB(255, 255, 255);
    
    my $code = pack('H*', '4883EC48');
    $code .= pack('H*', '48B9') . pack('Q', $g_pd3dDevice);
    $code .= pack('H*', '48C7C200000000');
    $code .= pack('H*', '49C7C000000000');
    $code .= pack('H*', '49C7C1') . pack('V', D3DCLEAR_TARGET);
    $code .= pack('H*', 'C7442420') . pack('V', $clear_color);
    $code .= pack('H*', 'C7442428') . pack('V', 0x3F800000);
    $code .= pack('H*', 'C744243000000000');
    $code .= pack('H*', '48B8') . pack('Q', $clear_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C448');
    $code .= pack('H*', 'C3');
    call_thunk($code);
    
    my $hr = com_call_0($g_pd3dDevice, IDirect3DDevice9_BeginScene);
    
    if ($hr == S_OK) {
        my $set_stream_addr = read_ptr($vtbl + IDirect3DDevice9_SetStreamSource * 8);
        
        $code = pack('H*', '4883EC38');
        $code .= pack('H*', '48B9') . pack('Q', $g_pd3dDevice);
        $code .= pack('H*', '48C7C200000000');
        $code .= pack('H*', '49B8') . pack('Q', $g_pVB);
        $code .= pack('H*', '49C7C100000000');
        $code .= pack('H*', 'C7442420') . pack('V', 20);
        $code .= pack('H*', '48B8') . pack('Q', $set_stream_addr);
        $code .= pack('H*', 'FFD0');
        $code .= pack('H*', '4883C438');
        $code .= pack('H*', 'C3');
        call_thunk($code);
        
        com_call_1($g_pd3dDevice, IDirect3DDevice9_SetFVF, D3DFVF_VERTEX);
        com_call_3($g_pd3dDevice, IDirect3DDevice9_DrawPrimitive, D3DPT_TRIANGLELIST, 0, 1);
        com_call_0($g_pd3dDevice, IDirect3DDevice9_EndScene);
    }
    
    com_call_4($g_pd3dDevice, IDirect3DDevice9_Present, 0, 0, 0, 0);
}

sub cleanup {
    if ($g_pVB) {
        com_call_0($g_pVB, IUnknown_Release);
        $g_pVB = 0;
    }
    if ($g_pd3dDevice) {
        com_call_0($g_pd3dDevice, IUnknown_Release);
        $g_pd3dDevice = 0;
    }
    if ($g_pD3D) {
        com_call_0($g_pD3D, IUnknown_Release);
        $g_pD3D = 0;
    }
}

# ============================================================
# Main
# ============================================================
print "Initializing...\n";

init_thunk_memory();
print "Thunk memory: ", sprintf("0x%X", $thunk_mem), "\n";

my $work_mem_size = 8192;
$work_mem = $VirtualAlloc->Call(0, $work_mem_size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
die "VirtualAlloc for work_mem failed" unless $work_mem;
$work_offset = 0;
print "Work memory: ", sprintf("0x%X", $work_mem), "\n";

eval {
    print "\n--- Creating Window ---\n";
    
    my $hinstance = $GetModuleHandleW->Call(0);
    print "hInstance: ", sprintf("0x%X", $hinstance), "\n";
    
    my $hcursor = $LoadCursorW->Call(0, IDC_ARROW);
    print "hCursor: ", sprintf("0x%X", $hcursor), "\n";
    
    my $user32_str = encode_utf16("user32.dll");
    my $user32 = $LoadLibraryW->Call($user32_str);
    my $defproc_addr = $GetProcAddress->Call($user32, "DefWindowProcW\0");
    print "DefWindowProcW: ", sprintf("0x%X", $defproc_addr), "\n";
    
    # IMPORTANT: Keep $class_name in scope - Perl's pack('p') returns pointer to the string
    my $class_name = encode_utf16("PerlD3D9Class");
    my $class_name_ptr = unpack('Q', pack('p', $class_name));
    print "Class name ptr: ", sprintf("0x%X", $class_name_ptr), "\n";
    
    # WNDCLASSEXW for 64-bit (80 bytes total)
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80,                        # cbSize
        CS_HREDRAW | CS_VREDRAW,   # style
        $defproc_addr,             # lpfnWndProc
        0,                         # cbClsExtra
        0,                         # cbWndExtra
        $hinstance,                # hInstance
        0,                         # hIcon
        $hcursor,                  # hCursor
        COLOR_WINDOW + 1,          # hbrBackground
        0,                         # lpszMenuName
        $class_name_ptr,           # lpszClassName
        0                          # hIconSm
    );
    print "WNDCLASSEX size: ", length($wndclass), " bytes\n";
    
    # CRITICAL: Pass the packed string directly to RegisterClassExW
    # Win32::API 'P' type expects a Perl string, NOT a numeric address
    my $class_atom = $RegisterClassExW->Call($wndclass);
    unless ($class_atom) {
        my $err = $GetLastError->Call();
        die sprintf("RegisterClassExW failed: 0x%08X\n", $err);
    }
    print "Window class registered, atom: $class_atom\n";
    
    my $window_title = encode_utf16("DirectX9 Perl Triangle");
    
    # CRITICAL: Pass UTF-16 strings directly for lpClassName and lpWindowName
    $hwnd = $CreateWindowExW->Call(
        0,                         # dwExStyle
        $class_name,               # lpClassName - UTF-16 string
        $window_title,             # lpWindowName - UTF-16 string
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
    
    $ShowWindow->Call($hwnd, SW_SHOWNORMAL);
    $UpdateWindow->Call($hwnd);
    print "Window shown\n";
    
    print "\n--- Initializing Direct3D9 ---\n";
    init_d3d();
    init_vb();
    
    print "\n=== DirectX9 Triangle Demo ===\n";
    print "Running for 5 seconds...\n\n";
    
    my $msg = "\0" x 48;
    my $start_time = time();
    
    while (time() - $start_time < 5) {
        while ($PeekMessageW->Call($msg, 0, 0, 0, PM_REMOVE)) {
            $TranslateMessage->Call($msg);
            $DispatchMessageW->Call($msg);
        }
        render();
        $Sleep->Call(16);
    }
    
    print "Done rendering.\n";
};

if ($@) {
    print "Error: $@\n";
}

cleanup();
free_thunk_memory();

print "Cleanup complete.\n";
