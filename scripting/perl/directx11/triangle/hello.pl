use strict;
use warnings;
use Win32::API;
use FFI::Platypus;
use Encode qw(encode);

# ============================================================
# 64-bit only implementation
# ============================================================
print "=== Perl DirectX11 Triangle via COM vtable (64-bit) ===\n\n";

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
    
    # D3D11 / DXGI constants
    D3D11_SDK_VERSION          => 7,
    D3D_DRIVER_TYPE_HARDWARE   => 1,
    D3D_DRIVER_TYPE_WARP       => 5,
    D3D_DRIVER_TYPE_REFERENCE  => 2,
    D3D_FEATURE_LEVEL_11_0     => 0xB000,
    
    DXGI_FORMAT_R8G8B8A8_UNORM     => 28,
    DXGI_FORMAT_R32G32B32_FLOAT    => 6,
    DXGI_FORMAT_R32G32B32A32_FLOAT => 2,
    DXGI_USAGE_RENDER_TARGET_OUTPUT => 0x00000020,
    
    D3D11_USAGE_DEFAULT       => 0,
    D3D11_BIND_VERTEX_BUFFER  => 0x00000001,
    D3D11_INPUT_PER_VERTEX_DATA => 0,
    D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST => 4,
    
    D3DCOMPILE_ENABLE_STRICTNESS => 0x00000002,
};

# COM vtable indices
use constant {
    # IDXGISwapChain
    IDXGISwapChain_Present   => 8,
    IDXGISwapChain_GetBuffer => 9,
    
    # ID3D11Device
    ID3D11Device_CreateBuffer           => 3,
    ID3D11Device_CreateRenderTargetView => 9,
    ID3D11Device_CreateInputLayout      => 11,
    ID3D11Device_CreateVertexShader     => 12,
    ID3D11Device_CreatePixelShader      => 15,
    
    # ID3D11DeviceContext
    ID3D11DeviceContext_PSSetShader           => 9,
    ID3D11DeviceContext_VSSetShader           => 11,
    ID3D11DeviceContext_Draw                  => 13,
    ID3D11DeviceContext_IASetInputLayout      => 17,
    ID3D11DeviceContext_IASetVertexBuffers    => 18,
    ID3D11DeviceContext_IASetPrimitiveTopology => 24,
    ID3D11DeviceContext_OMSetRenderTargets    => 33,
    ID3D11DeviceContext_RSSetViewports        => 44,
    ID3D11DeviceContext_ClearRenderTargetView => 50,
    
    # ID3DBlob
    ID3DBlob_GetBufferPointer => 3,
    ID3DBlob_GetBufferSize    => 4,
    
    # IUnknown
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

my $RegisterClassExW = Win32::API->new('user32', 'RegisterClassExW', 'P', 'I');
my $CreateWindowExW = Win32::API->new('user32', 'CreateWindowExW', 'NPPNNNNNNNNP', 'N');
my $LoadCursorW = Win32::API->new('user32', 'LoadCursorW', 'NN', 'N');
my $GetLastError = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $ShowWindow = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $UpdateWindow = Win32::API->new('user32', 'UpdateWindow', 'N', 'I');
my $GetClientRect = Win32::API->new('user32', 'GetClientRect', 'NP', 'I');
my $PeekMessageW = Win32::API->new('user32', 'PeekMessageW', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageW = Win32::API->new('user32', 'DispatchMessageW', 'P', 'N');
my $Sleep = Win32::API->new('kernel32', 'Sleep', 'N', 'V');

my $CoInitialize = Win32::API->new('ole32', 'CoInitialize', 'N', 'I');
my $CoUninitialize = Win32::API->new('ole32', 'CoUninitialize', '', 'V');

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

sub guid_from_string {
    my ($s) = @_;
    $s =~ s/[{}]//g;
    my @p = split /-/, $s;
    return pack('L S S', hex($p[0]), hex($p[1]), hex($p[2])) . pack('H*', $p[3] . $p[4]);
}

# ============================================================
# Thunk memory management
# ============================================================
my $thunk_mem;
my $thunk_size = 4096;

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
my $g_device;
my $g_context;
my $g_swap;
my $g_rtv;
my $g_vs;
my $g_ps;
my $g_layout;
my $g_vb;

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

sub com_call_2 {
    my ($obj, $vtbl_index, $arg1, $arg2) = @_;
    my $vtbl = read_ptr($obj);
    my $func_addr = read_ptr($vtbl + $vtbl_index * 8);
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $obj);
    $code .= pack('H*', '48BA') . pack('Q', $arg1);
    $code .= pack('H*', '49B8') . pack('Q', $arg2);
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

# ============================================================
# HLSL source
# ============================================================
my $HLSL_SRC = <<'HLSL';
struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT output = (VS_OUTPUT)0;
    output.position = position;
    output.color = color;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    return input.color;
}
HLSL

# ============================================================
# Shader compilation
# ============================================================
sub compile_hlsl {
    my ($entry, $target, $D3DCompile_addr) = @_;
    
    my $src = $HLSL_SRC;
    my $src_len = length($src);
    
    # Allocate memory for source and output pointers
    my $src_addr = alloc_work($src_len + 1);
    write_mem($src_addr, $src . "\0");
    
    my $source_name = "embedded.hlsl\0";
    my $source_name_addr = alloc_work(length($source_name));
    write_mem($source_name_addr, $source_name);
    
    my $entry_str = $entry . "\0";
    my $entry_addr = alloc_work(length($entry_str));
    write_mem($entry_addr, $entry_str);
    
    my $target_str = $target . "\0";
    my $target_addr = alloc_work(length($target_str));
    write_mem($target_addr, $target_str);
    
    my $code_blob_addr = alloc_work(8);
    write_mem($code_blob_addr, "\0" x 8);
    
    my $err_blob_addr = alloc_work(8);
    write_mem($err_blob_addr, "\0" x 8);
    
    # D3DCompile(src, srcSize, sourceName, defines, include, entry, target, flags1, flags2, &code, &err)
    my $code = pack('H*', '4883EC68');                          # sub rsp, 0x68
    $code .= pack('H*', '48B9') . pack('Q', $src_addr);         # mov rcx, src
    $code .= pack('H*', '48BA') . pack('Q', $src_len);          # mov rdx, srcSize
    $code .= pack('H*', '49B8') . pack('Q', $source_name_addr); # mov r8, sourceName
    $code .= pack('H*', '49C7C100000000');                      # mov r9, 0 (defines)
    # Stack args
    $code .= pack('H*', '48C744242000000000');                  # [rsp+0x20] = 0 (include)
    $code .= pack('H*', '48B8') . pack('Q', $entry_addr);
    $code .= pack('H*', '4889442428');                          # [rsp+0x28] = entry
    $code .= pack('H*', '48B8') . pack('Q', $target_addr);
    $code .= pack('H*', '4889442430');                          # [rsp+0x30] = target
    $code .= pack('H*', 'C7442438') . pack('V', D3DCOMPILE_ENABLE_STRICTNESS); # [rsp+0x38] = flags1
    $code .= pack('H*', 'C744244000000000');                    # [rsp+0x40] = 0 (flags2)
    $code .= pack('H*', '48B8') . pack('Q', $code_blob_addr);
    $code .= pack('H*', '4889442448');                          # [rsp+0x48] = &code
    $code .= pack('H*', '48B8') . pack('Q', $err_blob_addr);
    $code .= pack('H*', '4889442450');                          # [rsp+0x50] = &err
    $code .= pack('H*', '48B8') . pack('Q', $D3DCompile_addr);
    $code .= pack('H*', 'FFD0');                                # call rax
    $code .= pack('H*', '4883C468');                            # add rsp, 0x68
    $code .= pack('H*', 'C3');                                  # ret
    
    my $hr = call_thunk($code);
    
    my $code_blob = read_ptr($code_blob_addr);
    my $err_blob = read_ptr($err_blob_addr);
    
    if ($hr != S_OK) {
        my $msg = "D3DCompile failed for $entry";
        if ($err_blob) {
            my $err_ptr = com_call_0($err_blob, ID3DBlob_GetBufferPointer);
            if ($err_ptr) {
                my $err_text = read_mem($err_ptr, 256);
                $err_text =~ s/\0.*//s;
                $msg .= ": $err_text";
            }
            com_call_0($err_blob, IUnknown_Release);
        }
        die "$msg\n";
    }
    
    if ($err_blob) {
        com_call_0($err_blob, IUnknown_Release);
    }
    
    return $code_blob;
}

sub blob_ptr {
    my ($blob) = @_;
    my $vtbl = read_ptr($blob);
    my $func_addr = read_ptr($vtbl + ID3DBlob_GetBufferPointer * 8);
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $blob);
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    
    return call_thunk_ptr($code);
}

sub blob_size {
    my ($blob) = @_;
    my $vtbl = read_ptr($blob);
    my $func_addr = read_ptr($vtbl + ID3DBlob_GetBufferSize * 8);
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $blob);
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    
    return call_thunk_ptr($code);
}

# ============================================================
# D3D11 initialization
# ============================================================
sub init_d3d {
    # Load DLLs
    my $d3d11_str = encode_utf16("d3d11.dll");
    my $hD3D11 = $LoadLibraryW->Call($d3d11_str);
    die "LoadLibraryW(d3d11.dll) failed\n" unless $hD3D11;
    print "d3d11.dll: ", sprintf("0x%X", $hD3D11), "\n";
    
    my $d3dcompiler_str = encode_utf16("d3dcompiler_47.dll");
    my $hD3DCompiler = $LoadLibraryW->Call($d3dcompiler_str);
    unless ($hD3DCompiler) {
        $d3dcompiler_str = encode_utf16("d3dcompiler_43.dll");
        $hD3DCompiler = $LoadLibraryW->Call($d3dcompiler_str);
    }
    die "LoadLibraryW(d3dcompiler) failed\n" unless $hD3DCompiler;
    print "d3dcompiler: ", sprintf("0x%X", $hD3DCompiler), "\n";
    
    my $D3D11CreateDeviceAndSwapChain = $GetProcAddress->Call($hD3D11, "D3D11CreateDeviceAndSwapChain\0");
    die "GetProcAddress(D3D11CreateDeviceAndSwapChain) failed\n" unless $D3D11CreateDeviceAndSwapChain;
    
    my $D3DCompile = $GetProcAddress->Call($hD3DCompiler, "D3DCompile\0");
    die "GetProcAddress(D3DCompile) failed\n" unless $D3DCompile;
    
    # Get client rect
    my $rc = "\0" x 16;
    $GetClientRect->Call($hwnd, $rc);
    my ($left, $top, $right, $bottom) = unpack('l l l l', $rc);
    my $width = $right - $left;
    my $height = $bottom - $top;
    print "Client rect: $width x $height\n";
    
    # DXGI_SWAP_CHAIN_DESC structure (aligned for 64-bit)
    # BufferDesc: DXGI_MODE_DESC (28 bytes)
    #   Width(4), Height(4), RefreshRate(8), Format(4), ScanlineOrdering(4), Scaling(4)
    # SampleDesc: DXGI_SAMPLE_DESC (8 bytes) - Count(4), Quality(4)
    # BufferUsage(4), BufferCount(4)
    # [4 bytes padding for HWND alignment]
    # OutputWindow(8), Windowed(4), SwapEffect(4), Flags(4), [4 bytes end padding]
    # Total: 72 bytes
    
    my $sd_addr = alloc_work(80);
    my $sd = pack('L L L L L L L L L L L x4 Q L L L x4',
        $width,                          # BufferDesc.Width
        $height,                         # BufferDesc.Height
        60, 1,                           # RefreshRate (60/1)
        DXGI_FORMAT_R8G8B8A8_UNORM,      # Format
        0, 0,                            # ScanlineOrdering, Scaling
        1, 0,                            # SampleDesc (Count=1, Quality=0)
        DXGI_USAGE_RENDER_TARGET_OUTPUT, # BufferUsage
        1,                               # BufferCount
        # x4 = 4 bytes padding for HWND 8-byte alignment
        $hwnd,                           # OutputWindow (8 bytes)
        1,                               # Windowed = TRUE
        0, 0                             # SwapEffect, Flags
        # x4 = end padding
    );
    print "DXGI_SWAP_CHAIN_DESC size: ", length($sd), " bytes\n";
    write_mem($sd_addr, $sd);
    
    # Feature levels
    my $feature_levels_addr = alloc_work(8);
    write_mem($feature_levels_addr, pack('L', D3D_FEATURE_LEVEL_11_0));
    
    my $created_level_addr = alloc_work(4);
    write_mem($created_level_addr, "\0" x 4);
    
    # Output pointers
    my $swap_addr = alloc_work(8);
    my $device_addr = alloc_work(8);
    my $context_addr = alloc_work(8);
    write_mem($swap_addr, "\0" x 8);
    write_mem($device_addr, "\0" x 8);
    write_mem($context_addr, "\0" x 8);
    
    # Try different driver types
    my @driver_types = (D3D_DRIVER_TYPE_HARDWARE, D3D_DRIVER_TYPE_WARP, D3D_DRIVER_TYPE_REFERENCE);
    my $hr = -1;
    
    for my $driver_type (@driver_types) {
        # Reset output pointers
        write_mem($swap_addr, "\0" x 8);
        write_mem($device_addr, "\0" x 8);
        write_mem($context_addr, "\0" x 8);
        
        # D3D11CreateDeviceAndSwapChain call
        my $code = pack('H*', '4883EC68');                              # sub rsp, 0x68
        $code .= pack('H*', '48C7C100000000');                          # mov rcx, 0 (Adapter)
        $code .= pack('H*', '48C7C2') . pack('V', $driver_type);        # mov rdx, DriverType
        $code .= pack('H*', '49C7C000000000');                          # mov r8, 0 (Software)
        $code .= pack('H*', '49C7C100000000');                          # mov r9, 0 (Flags)
        # Stack args
        $code .= pack('H*', '48B8') . pack('Q', $feature_levels_addr);
        $code .= pack('H*', '4889442420');                              # [rsp+0x20] = pFeatureLevels
        $code .= pack('H*', 'C744242801000000');                        # [rsp+0x28] = 1 (FeatureLevels count)
        $code .= pack('H*', 'C7442430') . pack('V', D3D11_SDK_VERSION); # [rsp+0x30] = SDKVersion
        $code .= pack('H*', '48B8') . pack('Q', $sd_addr);
        $code .= pack('H*', '4889442438');                              # [rsp+0x38] = pSwapChainDesc
        $code .= pack('H*', '48B8') . pack('Q', $swap_addr);
        $code .= pack('H*', '4889442440');                              # [rsp+0x40] = ppSwapChain
        $code .= pack('H*', '48B8') . pack('Q', $device_addr);
        $code .= pack('H*', '4889442448');                              # [rsp+0x48] = ppDevice
        $code .= pack('H*', '48B8') . pack('Q', $created_level_addr);
        $code .= pack('H*', '4889442450');                              # [rsp+0x50] = pFeatureLevel
        $code .= pack('H*', '48B8') . pack('Q', $context_addr);
        $code .= pack('H*', '4889442458');                              # [rsp+0x58] = ppContext
        $code .= pack('H*', '48B8') . pack('Q', $D3D11CreateDeviceAndSwapChain);
        $code .= pack('H*', 'FFD0');                                    # call rax
        $code .= pack('H*', '4883C468');                                # add rsp, 0x68
        $code .= pack('H*', 'C3');                                      # ret
        
        $hr = call_thunk($code);
        last if $hr == S_OK;
    }
    
    die sprintf("D3D11CreateDeviceAndSwapChain failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_swap = read_ptr($swap_addr);
    $g_device = read_ptr($device_addr);
    $g_context = read_ptr($context_addr);
    
    print "IDXGISwapChain: ", sprintf("0x%X", $g_swap), "\n";
    print "ID3D11Device: ", sprintf("0x%X", $g_device), "\n";
    print "ID3D11DeviceContext: ", sprintf("0x%X", $g_context), "\n";
    
    # Get back buffer
    my $backbuf_addr = alloc_work(8);
    write_mem($backbuf_addr, "\0" x 8);
    
    my $iid_texture2d = guid_from_string("{6f15aaf2-d208-4e89-9ab4-489535d34f9c}");
    my $iid_addr = alloc_work(16);
    write_mem($iid_addr, $iid_texture2d);
    
    # IDXGISwapChain::GetBuffer(0, IID_ID3D11Texture2D, &backbuf)
    my $swap_vtbl = read_ptr($g_swap);
    my $get_buffer_addr = read_ptr($swap_vtbl + IDXGISwapChain_GetBuffer * 8);
    
    my $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_swap);
    $code .= pack('H*', '48C7C200000000');                    # Buffer index = 0
    $code .= pack('H*', '49B8') . pack('Q', $iid_addr);
    $code .= pack('H*', '49B9') . pack('Q', $backbuf_addr);
    $code .= pack('H*', '48B8') . pack('Q', $get_buffer_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    die sprintf("SwapChain.GetBuffer failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    my $backbuf = read_ptr($backbuf_addr);
    print "Back buffer: ", sprintf("0x%X", $backbuf), "\n";
    
    # Create Render Target View
    my $rtv_addr = alloc_work(8);
    write_mem($rtv_addr, "\0" x 8);
    
    my $device_vtbl = read_ptr($g_device);
    my $create_rtv_addr = read_ptr($device_vtbl + ID3D11Device_CreateRenderTargetView * 8);
    
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $backbuf);
    $code .= pack('H*', '49C7C000000000');                    # pDesc = NULL
    $code .= pack('H*', '49B9') . pack('Q', $rtv_addr);
    $code .= pack('H*', '48B8') . pack('Q', $create_rtv_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    
    # Release back buffer
    com_call_0($backbuf, IUnknown_Release);
    
    die sprintf("CreateRenderTargetView failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_rtv = read_ptr($rtv_addr);
    print "Render Target View: ", sprintf("0x%X", $g_rtv), "\n";
    
    # OMSetRenderTargets
    my $rtv_array_addr = alloc_work(8);
    write_mem($rtv_array_addr, pack('Q', $g_rtv));
    
    my $ctx_vtbl = read_ptr($g_context);
    my $om_set_addr = read_ptr($ctx_vtbl + ID3D11DeviceContext_OMSetRenderTargets * 8);
    
    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_context);
    $code .= pack('H*', '48C7C201000000');                    # NumViews = 1
    $code .= pack('H*', '49B8') . pack('Q', $rtv_array_addr);
    $code .= pack('H*', '49C7C100000000');                    # pDepthStencilView = NULL
    $code .= pack('H*', '48B8') . pack('Q', $om_set_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    call_thunk($code);
    
    # RSSetViewports
    my $vp_addr = alloc_work(24);
    my $vp = pack('f f f f f f', 0.0, 0.0, $width, $height, 0.0, 1.0);
    write_mem($vp_addr, $vp);
    
    my $rs_vp_addr = read_ptr($ctx_vtbl + ID3D11DeviceContext_RSSetViewports * 8);
    
    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_context);
    $code .= pack('H*', '48C7C201000000');                    # NumViewports = 1
    $code .= pack('H*', '49B8') . pack('Q', $vp_addr);
    $code .= pack('H*', '48B8') . pack('Q', $rs_vp_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    call_thunk($code);
    
    # Compile shaders
    print "Compiling shaders...\n";
    my $vs_blob = compile_hlsl("VS", "vs_4_0", $D3DCompile);
    my $ps_blob = compile_hlsl("PS", "ps_4_0", $D3DCompile);
    print "Shaders compiled\n";
    
    my $vs_ptr = blob_ptr($vs_blob);
    my $vs_size = blob_size($vs_blob);
    my $ps_ptr = blob_ptr($ps_blob);
    my $ps_size = blob_size($ps_blob);
    
    # Create Vertex Shader
    my $vs_addr = alloc_work(8);
    write_mem($vs_addr, "\0" x 8);
    
    my $create_vs_addr = read_ptr($device_vtbl + ID3D11Device_CreateVertexShader * 8);
    
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $vs_ptr);
    $code .= pack('H*', '49B8') . pack('Q', $vs_size);
    $code .= pack('H*', '49C7C100000000');                    # pClassLinkage = NULL
    $code .= pack('H*', '48B8') . pack('Q', $vs_addr);
    $code .= pack('H*', '4889442420');                        # [rsp+0x20] = ppVertexShader
    $code .= pack('H*', '48B8') . pack('Q', $create_vs_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    die sprintf("CreateVertexShader failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_vs = read_ptr($vs_addr);
    print "Vertex Shader: ", sprintf("0x%X", $g_vs), "\n";
    
    # Create Input Layout
    # D3D11_INPUT_ELEMENT_DESC: SemanticName(8), SemanticIndex(4), Format(4), InputSlot(4), 
    #                          AlignedByteOffset(4), InputSlotClass(4), InstanceDataStepRate(4)
    # Total: 32 bytes per element
    my $position_str = "POSITION\0";
    my $color_str = "COLOR\0";
    my $position_addr = alloc_work(16);
    my $color_addr = alloc_work(16);
    write_mem($position_addr, $position_str);
    write_mem($color_addr, $color_str);
    
    my $layout_desc_addr = alloc_work(64);
    my $layout_desc = pack('Q L L L L L L',
        $position_addr,              # SemanticName
        0,                           # SemanticIndex
        DXGI_FORMAT_R32G32B32_FLOAT, # Format (float3)
        0,                           # InputSlot
        0,                           # AlignedByteOffset
        D3D11_INPUT_PER_VERTEX_DATA, # InputSlotClass
        0                            # InstanceDataStepRate
    );
    $layout_desc .= pack('Q L L L L L L',
        $color_addr,                     # SemanticName
        0,                               # SemanticIndex
        DXGI_FORMAT_R32G32B32A32_FLOAT,  # Format (float4)
        0,                               # InputSlot
        12,                              # AlignedByteOffset (after float3)
        D3D11_INPUT_PER_VERTEX_DATA,     # InputSlotClass
        0                                # InstanceDataStepRate
    );
    write_mem($layout_desc_addr, $layout_desc);
    
    my $layout_addr = alloc_work(8);
    write_mem($layout_addr, "\0" x 8);
    
    my $create_il_addr = read_ptr($device_vtbl + ID3D11Device_CreateInputLayout * 8);
    
    $code = pack('H*', '4883EC48');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $layout_desc_addr);
    $code .= pack('H*', '49C7C002000000');                    # NumElements = 2
    $code .= pack('H*', '49B9') . pack('Q', $vs_ptr);
    $code .= pack('H*', '48B8') . pack('Q', $vs_size);
    $code .= pack('H*', '4889442420');                        # [rsp+0x20] = BytecodeLength
    $code .= pack('H*', '48B8') . pack('Q', $layout_addr);
    $code .= pack('H*', '4889442428');                        # [rsp+0x28] = ppInputLayout
    $code .= pack('H*', '48B8') . pack('Q', $create_il_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C448');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    die sprintf("CreateInputLayout failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_layout = read_ptr($layout_addr);
    print "Input Layout: ", sprintf("0x%X", $g_layout), "\n";
    
    # IASetInputLayout
    com_call_1($g_context, ID3D11DeviceContext_IASetInputLayout, $g_layout);
    
    # Create Pixel Shader
    my $ps_out_addr = alloc_work(8);
    write_mem($ps_out_addr, "\0" x 8);
    
    my $create_ps_addr = read_ptr($device_vtbl + ID3D11Device_CreatePixelShader * 8);
    
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $ps_ptr);
    $code .= pack('H*', '49B8') . pack('Q', $ps_size);
    $code .= pack('H*', '49C7C100000000');                    # pClassLinkage = NULL
    $code .= pack('H*', '48B8') . pack('Q', $ps_out_addr);
    $code .= pack('H*', '4889442420');                        # [rsp+0x20] = ppPixelShader
    $code .= pack('H*', '48B8') . pack('Q', $create_ps_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    die sprintf("CreatePixelShader failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_ps = read_ptr($ps_out_addr);
    print "Pixel Shader: ", sprintf("0x%X", $g_ps), "\n";
    
    # Release shader blobs
    com_call_0($vs_blob, IUnknown_Release);
    com_call_0($ps_blob, IUnknown_Release);
    
    # Create Vertex Buffer
    # Vertex: x,y,z (float3) + r,g,b,a (float4) = 28 bytes
    my $vertex_size = 28;
    my @vertices = (
        # x, y, z, r, g, b, a
        [ 0.0,  0.5, 0.5, 1.0, 0.0, 0.0, 1.0],  # Top - Red
        [ 0.5, -0.5, 0.5, 0.0, 1.0, 0.0, 1.0],  # Bottom Right - Green
        [-0.5, -0.5, 0.5, 0.0, 0.0, 1.0, 1.0],  # Bottom Left - Blue
    );
    
    my $vertex_data_addr = alloc_work($vertex_size * 3);
    my $vertex_data = '';
    for my $v (@vertices) {
        $vertex_data .= pack('f7', @$v);
    }
    write_mem($vertex_data_addr, $vertex_data);
    
    # D3D11_BUFFER_DESC
    my $bd_addr = alloc_work(24);
    my $bd = pack('L L L L L L',
        $vertex_size * 3,        # ByteWidth
        D3D11_USAGE_DEFAULT,     # Usage
        D3D11_BIND_VERTEX_BUFFER,# BindFlags
        0,                       # CPUAccessFlags
        0,                       # MiscFlags
        0                        # StructureByteStride
    );
    write_mem($bd_addr, $bd);
    
    # D3D11_SUBRESOURCE_DATA
    my $init_data_addr = alloc_work(24);
    my $init_data = pack('Q L L', $vertex_data_addr, 0, 0);
    write_mem($init_data_addr, $init_data);
    
    my $vb_addr = alloc_work(8);
    write_mem($vb_addr, "\0" x 8);
    
    my $create_buf_addr = read_ptr($device_vtbl + ID3D11Device_CreateBuffer * 8);
    
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $bd_addr);
    $code .= pack('H*', '49B8') . pack('Q', $init_data_addr);
    $code .= pack('H*', '49B9') . pack('Q', $vb_addr);
    $code .= pack('H*', '48B8') . pack('Q', $create_buf_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    die sprintf("CreateBuffer failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_vb = read_ptr($vb_addr);
    print "Vertex Buffer: ", sprintf("0x%X", $g_vb), "\n";
    
    # IASetVertexBuffers
    my $vb_array_addr = alloc_work(8);
    write_mem($vb_array_addr, pack('Q', $g_vb));
    
    my $stride_addr = alloc_work(4);
    write_mem($stride_addr, pack('L', $vertex_size));
    
    my $offset_addr = alloc_work(4);
    write_mem($offset_addr, pack('L', 0));
    
    my $ia_vb_addr = read_ptr($ctx_vtbl + ID3D11DeviceContext_IASetVertexBuffers * 8);
    
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_context);
    $code .= pack('H*', '48C7C200000000');                    # StartSlot = 0
    $code .= pack('H*', '49C7C001000000');                    # NumBuffers = 1
    $code .= pack('H*', '49B9') . pack('Q', $vb_array_addr);
    $code .= pack('H*', '48B8') . pack('Q', $stride_addr);
    $code .= pack('H*', '4889442420');                        # [rsp+0x20] = pStrides
    $code .= pack('H*', '48B8') . pack('Q', $offset_addr);
    $code .= pack('H*', '4889442428');                        # [rsp+0x28] = pOffsets
    $code .= pack('H*', '48B8') . pack('Q', $ia_vb_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    call_thunk($code);
    
    # IASetPrimitiveTopology
    com_call_1($g_context, ID3D11DeviceContext_IASetPrimitiveTopology, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    
    print "D3D11 initialization complete\n";
}

# ============================================================
# Render
# ============================================================
sub render {
    return unless $g_context && $g_rtv;
    
    my $ctx_vtbl = read_ptr($g_context);
    
    # ClearRenderTargetView
    my $color_addr = alloc_work(16);
    write_mem($color_addr, pack('f4', 1.0, 1.0, 1.0, 1.0));  # White
    
    my $clear_rtv_addr = read_ptr($ctx_vtbl + ID3D11DeviceContext_ClearRenderTargetView * 8);
    
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_context);
    $code .= pack('H*', '48BA') . pack('Q', $g_rtv);
    $code .= pack('H*', '49B8') . pack('Q', $color_addr);
    $code .= pack('H*', '48B8') . pack('Q', $clear_rtv_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    call_thunk($code);
    
    # VSSetShader
    my $vs_set_addr = read_ptr($ctx_vtbl + ID3D11DeviceContext_VSSetShader * 8);
    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_context);
    $code .= pack('H*', '48BA') . pack('Q', $g_vs);
    $code .= pack('H*', '49C7C000000000');                    # ppClassInstances = NULL
    $code .= pack('H*', '49C7C100000000');                    # NumClassInstances = 0
    $code .= pack('H*', '48B8') . pack('Q', $vs_set_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    call_thunk($code);
    
    # PSSetShader
    my $ps_set_addr = read_ptr($ctx_vtbl + ID3D11DeviceContext_PSSetShader * 8);
    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_context);
    $code .= pack('H*', '48BA') . pack('Q', $g_ps);
    $code .= pack('H*', '49C7C000000000');                    # ppClassInstances = NULL
    $code .= pack('H*', '49C7C100000000');                    # NumClassInstances = 0
    $code .= pack('H*', '48B8') . pack('Q', $ps_set_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    call_thunk($code);
    
    # Draw(3, 0)
    com_call_2($g_context, ID3D11DeviceContext_Draw, 3, 0);
    
    # Present(0, 0)
    com_call_2($g_swap, IDXGISwapChain_Present, 0, 0);
}

# ============================================================
# Cleanup
# ============================================================
sub cleanup {
    com_call_0($g_vb, IUnknown_Release) if $g_vb;
    com_call_0($g_layout, IUnknown_Release) if $g_layout;
    com_call_0($g_vs, IUnknown_Release) if $g_vs;
    com_call_0($g_ps, IUnknown_Release) if $g_ps;
    com_call_0($g_rtv, IUnknown_Release) if $g_rtv;
    com_call_0($g_swap, IUnknown_Release) if $g_swap;
    com_call_0($g_context, IUnknown_Release) if $g_context;
    com_call_0($g_device, IUnknown_Release) if $g_device;
}

# ============================================================
# Main
# ============================================================
print "Initializing...\n";

$CoInitialize->Call(0);

init_thunk_memory();
print "Thunk memory: ", sprintf("0x%X", $thunk_mem), "\n";

my $work_mem_size = 65536;
$work_mem = $VirtualAlloc->Call(0, $work_mem_size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
die "VirtualAlloc for work_mem failed" unless $work_mem;
$work_offset = 0;
print "Work memory: ", sprintf("0x%X", $work_mem), "\n";

eval {
    print "\n--- Creating Window ---\n";
    
    my $hinstance = $GetModuleHandleW->Call(0);
    my $hcursor = $LoadCursorW->Call(0, IDC_ARROW);
    
    my $user32_str = encode_utf16("user32.dll");
    my $user32 = $LoadLibraryW->Call($user32_str);
    my $defproc_addr = $GetProcAddress->Call($user32, "DefWindowProcW\0");
    
    my $class_name = encode_utf16("PerlD3D11Class");
    my $class_name_ptr = unpack('Q', pack('p', $class_name));
    
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80, CS_HREDRAW | CS_VREDRAW, $defproc_addr,
        0, 0, $hinstance, 0, $hcursor, 0, 0, $class_name_ptr, 0
    );
    
    my $class_atom = $RegisterClassExW->Call($wndclass);
    die sprintf("RegisterClassExW failed: 0x%08X\n", $GetLastError->Call()) unless $class_atom;
    print "Window class registered\n";
    
    my $window_title = encode_utf16("DirectX11 Perl Triangle");
    
    $hwnd = $CreateWindowExW->Call(
        0, $class_name, $window_title, WS_OVERLAPPEDWINDOW,
        100, 100, 640, 480, 0, 0, $hinstance, 0
    );
    die sprintf("CreateWindowExW failed: 0x%08X\n", $GetLastError->Call()) unless $hwnd;
    print "Window created: ", sprintf("0x%X", $hwnd), "\n";
    
    $ShowWindow->Call($hwnd, SW_SHOWNORMAL);
    $UpdateWindow->Call($hwnd);
    print "Window shown\n";
    
    print "\n--- Initializing Direct3D 11 ---\n";
    init_d3d();
    
    print "\n=== DirectX11 Triangle Demo ===\n";
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
$CoUninitialize->Call();

print "Cleanup complete.\n";
