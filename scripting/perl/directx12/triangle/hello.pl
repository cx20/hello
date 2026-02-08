use strict;
use warnings;
use Win32::API;
use FFI::Platypus;
use Encode qw(encode decode);

# ============================================================
# 64-bit only implementation
# ============================================================
print "=== Perl DirectX12 Triangle via COM vtable (64-bit) ===\n\n";

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
    
    # DirectX12 constants
    D3D12_COMMAND_LIST_TYPE_DIRECT => 0,
    D3D12_COMMAND_QUEUE_FLAG_NONE  => 0,
    D3D12_DESCRIPTOR_HEAP_TYPE_RTV => 2,
    D3D12_DESCRIPTOR_HEAP_FLAG_NONE => 0,
    D3D12_RESOURCE_STATE_PRESENT   => 0,
    D3D12_RESOURCE_STATE_RENDER_TARGET => 4,
    D3D12_RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER => 0x1,
    D3D12_RESOURCE_STATE_INDEX_BUFFER => 0x2,
    D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE => 0x40,
    D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE => 0x80,
    D3D12_RESOURCE_STATE_INDIRECT_ARGUMENT => 0x200,
    D3D12_RESOURCE_STATE_COPY_SOURCE => 0x800,
    D3D12_RESOURCE_STATE_GENERIC_READ => 0xAC3,
    D3D12_HEAP_TYPE_UPLOAD        => 2,
    D3D12_RESOURCE_DIMENSION_BUFFER => 1,
    D3D12_TEXTURE_LAYOUT_ROW_MAJOR => 1,
    D3D12_RESOURCE_FLAG_NONE       => 0,
    D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA => 0,
    D3D12_RESOURCE_BARRIER_FLAG_NONE => 0,
    D3D12_RESOURCE_BARRIER_TYPE_TRANSITION => 0,
    D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES => 0xFFFFFFFF,
    D3D12_FENCE_FLAG_NONE          => 0,
    D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT => 0x1,
    D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE => 3,
    D3D12_FILL_MODE_SOLID => 3,
    D3D12_CULL_MODE_NONE => 1,
    D3D12_BLEND_ONE => 2,
    D3D12_BLEND_ZERO => 1,
    D3D12_BLEND_OP_ADD => 1,
    D3D12_LOGIC_OP_NOOP => 4,
    D3D12_COLOR_WRITE_ENABLE_ALL => 0x0F,
    D3D12_COMPARISON_FUNC_LESS => 2,
    D3D12_DEPTH_WRITE_MASK_ALL => 1,
    D3D12_STENCIL_OP_KEEP => 1,
    D3D12_PIPELINE_STATE_FLAG_NONE => 0,
    
    FRAMES => 2,
    
    DXGI_FORMAT_R8G8B8A8_UNORM => 28,
    DXGI_FORMAT_R32G32B32_FLOAT => 6,
    DXGI_FORMAT_R32G32B32A32_FLOAT => 2,
    DXGI_SWAP_EFFECT_FLIP_DISCARD => 4,
    DXGI_USAGE_RENDER_TARGET_OUTPUT => 32,
    DXGI_MODE_SCALING_UNSPECIFIED => 0,
    DXGI_SCALING_STRETCH => 0,
    DXGI_ALPHA_MODE_UNSPECIFIED => 0,
    DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH => 2,
    DXGI_SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT => 0x40,
    
    D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST => 4,
    D3DCOMPILE_ENABLE_STRICTNESS => 0x00000002,
    D3D_ROOT_SIGNATURE_VERSION_1 => 1,
    
    # Event constants
    EVENT_ALL_ACCESS => 0x1F0003,
};

# COM vtable indices for DirectX12
use constant {
    # IDXGISwapChain3
    IDXGISwapChain_Present => 8,
    IDXGISwapChain_GetBuffer => 9,
    IDXGISwapChain3_GetCurrentBackBufferIndex => 36,
    
    # ID3D12Device
    ID3D12Device_CreateCommandQueue => 8,
    ID3D12Device_CreateCommandAllocator => 9,
    ID3D12Device_CreateGraphicsPipelineState => 10,
    ID3D12Device_CreateCommandList => 12,
    ID3D12Device_CreateDescriptorHeap => 14,
    ID3D12Device_GetDescriptorHandleIncrementSize => 15,
    ID3D12Device_CreateRootSignature => 16,
    ID3D12Device_CreateCommittedResource => 27,
    ID3D12Device_CreateFence => 36,
    ID3D12Device_CreateRenderTargetView => 20,
    
    # ID3D12GraphicsCommandList
    ID3D12GraphicsCommandList_Close => 9,
    ID3D12GraphicsCommandList_Reset => 10,
    ID3D12GraphicsCommandList_SetPipelineState => 25,
    ID3D12GraphicsCommandList_ResourceBarrier => 26,
    ID3D12GraphicsCommandList_SetDescriptorHeaps => 28,
    ID3D12GraphicsCommandList_SetGraphicsRootSignature => 30,
    ID3D12GraphicsCommandList_IASetPrimitiveTopology => 20,
    ID3D12GraphicsCommandList_IASetVertexBuffers => 44,
    ID3D12GraphicsCommandList_RSSetViewports => 21,
    ID3D12GraphicsCommandList_RSSetScissorRects => 22,
    ID3D12GraphicsCommandList_OMSetRenderTargets => 46,
    ID3D12GraphicsCommandList_ClearRenderTargetView => 48,
    ID3D12GraphicsCommandList_DrawInstanced => 12,

    # ID3D12CommandAllocator
    ID3D12CommandAllocator_Reset => 8,
    
    # ID3D12CommandQueue
    ID3D12CommandQueue_ExecuteCommandLists => 10,
    ID3D12CommandQueue_Signal => 14,
    
    # ID3D12Fence
    ID3D12Fence_GetCompletedValue => 8,
    ID3D12Fence_SetEventOnCompletion => 9,
    
    # ID3D12Resource
    ID3D12Resource_Map => 8,
    ID3D12Resource_Unmap => 9,
    ID3D12Resource_GetGPUVirtualAddress => 11,

    # ID3D12DescriptorHeap
    ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart => 9,

    # ID3DBlob
    ID3DBlob_GetBufferPointer => 3,
    ID3DBlob_GetBufferSize => 4,
    
    # IDXGIFactory
    IDXGIFactory_CreateSwapChain => 10,
    IDXGIFactory2_CreateSwapChainForHwnd => 15,
    
    # IUnknown
    IUnknown_QueryInterface => 0,
    IUnknown_AddRef => 1,
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
my $DefWindowProcW = Win32::API->new('user32', 'DefWindowProcW', 'NNNN', 'N');
my $IsWindow = Win32::API->new('user32', 'IsWindow', 'N', 'I');
my $GetLastError = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $ShowWindow = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $UpdateWindow = Win32::API->new('user32', 'UpdateWindow', 'N', 'I');
my $GetClientRect = Win32::API->new('user32', 'GetClientRect', 'NP', 'I');
my $PeekMessageW = Win32::API->new('user32', 'PeekMessageW', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageW = Win32::API->new('user32', 'DispatchMessageW', 'P', 'N');
my $Sleep = Win32::API->new('kernel32', 'Sleep', 'N', 'V');
my $WaitForSingleObject = Win32::API->new('kernel32', 'WaitForSingleObject', 'NN', 'N');

my $D3DCompile = Win32::API->new('d3dcompiler_47', 'D3DCompile', 'PNPPPPPNNPP', 'N');
if (!$D3DCompile) {
    $D3DCompile = Win32::API->new('d3dcompiler_43', 'D3DCompile', 'PNPPPPPNNPP', 'N');
}
my $D3DCompile_addr = 0;
my $hD3DCompiler = 0;
my $D3D12SerializeRootSignature = Win32::API->new('d3d12', 'D3D12SerializeRootSignature', 'PNPP', 'N');

# Debug output via OutputDebugStringA
my $OutputDebugStringA = Win32::API->new('kernel32', 'OutputDebugStringA', 'P', 'V');

# Alternative: DBWIN_BUFFER based debug output
my $CreateEventA = Win32::API->new('kernel32', 'CreateEventA', 'PIIN', 'N');
my $SetEvent = Win32::API->new('kernel32', 'SetEvent', 'N', 'I');
my $OpenFileMappingA = Win32::API->new('kernel32', 'OpenFileMappingA', 'NIP', 'N');
my $MapViewOfFile = Win32::API->new('kernel32', 'MapViewOfFile', 'NNNN', 'N');

my $CoInitialize = Win32::API->new('ole32', 'CoInitialize', 'N', 'I');
my $CoUninitialize = Win32::API->new('ole32', 'CoUninitialize', '', 'V');

# ============================================================
# Test OutputDebugStringA immediately
# ============================================================
print "Debug output will be sent to OutputDebugStringA (DebugView)\n\n";
if ($OutputDebugStringA) {
    eval {
        $OutputDebugStringA->Call("Testing OutputDebugStringA from Perl\0");
        print "[SUCCESS] OutputDebugStringA call completed\n";
    };
    if ($@) {
        print "[ERROR] OutputDebugStringA failed: $@\n";
    }
} else {
    print "[ERROR] OutputDebugStringA not loaded\n";
}

# ============================================================
# Helper functions
# ============================================================
my $debugoutput_enabled = 1;
my $debug_in_render = 0;

sub debug_print {
    my ($msg) = @_;
    my $timestamp = scalar(localtime);
    print "[$timestamp] [DEBUG] $msg\n";
    
    # Try to output to debugger via OutputDebugStringA
    if ($debugoutput_enabled && $OutputDebugStringA) {
        # Encode message as Windows-1252 (ANSI) to avoid Unicode issues
        my $ansi_msg = eval { encode('cp1252', $msg) } // $msg;
        my $debug_msg = "[Perl-D3D12] $ansi_msg\0";
        
        eval {
            $OutputDebugStringA->Call($debug_msg);
        };
        if ($@) {
            warn "OutputDebugStringA failed: $@\n";
            $debugoutput_enabled = 0;
        }
    }
}

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
# HLSL and shader helpers
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

sub blob_ptr {
    my ($blob) = @_;
    return com_call_0_ptr($blob, ID3DBlob_GetBufferPointer);
}

sub blob_size {
    my ($blob) = @_;
    return com_call_0_ptr($blob, ID3DBlob_GetBufferSize);
}

sub compile_hlsl {
    my ($entry, $target) = @_;
    if (!$D3DCompile_addr) {
        my $d3dcompiler47 = encode_utf16("d3dcompiler_47.dll");
        $hD3DCompiler = $LoadLibraryW->Call($d3dcompiler47);
        if (!$hD3DCompiler) {
            my $d3dcompiler43 = encode_utf16("d3dcompiler_43.dll");
            $hD3DCompiler = $LoadLibraryW->Call($d3dcompiler43);
        }
        die "LoadLibraryW(d3dcompiler_47/43.dll) failed\n" unless $hD3DCompiler;

        $D3DCompile_addr = $GetProcAddress->Call($hD3DCompiler, "D3DCompile\0");
        die "GetProcAddress(D3DCompile) failed\n" unless $D3DCompile_addr;
    }

    my $src = $HLSL_SRC;
    my $src_len = length($src);
    my $src_ptr = alloc_work($src_len);
    write_mem($src_ptr, $src);

    my $name_str = "embedded.hlsl\0";
    my $name_ptr = alloc_work(length($name_str));
    write_mem($name_ptr, $name_str);

    my $entry_str = "$entry\0";
    my $entry_ptr = alloc_work(length($entry_str));
    write_mem($entry_ptr, $entry_str);

    my $target_str = "$target\0";
    my $target_ptr = alloc_work(length($target_str));
    write_mem($target_ptr, $target_str);

    my $code_addr = alloc_work(8);
    write_mem($code_addr, "\0" x 8);
    my $err_addr = alloc_work(8);
    write_mem($err_addr, "\0" x 8);

    my $d3dcompile = $ffi->function($D3DCompile_addr => [
        'opaque',  # pSrcData
        'size_t',  # SrcDataSize
        'opaque',  # pSourceName
        'opaque',  # pDefines
        'opaque',  # pInclude
        'opaque',  # pEntrypoint
        'opaque',  # pTarget
        'uint32',  # Flags1
        'uint32',  # Flags2
        'opaque',  # ppCode
        'opaque'   # ppErrorMsgs
    ] => 'uint32');

    my $hr = $d3dcompile->call(
        $src_ptr,
        $src_len,
        $name_ptr,
        0,
        0,
        $entry_ptr,
        $target_ptr,
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        $code_addr,
        $err_addr
    );

    if ($hr != 0) {
        my $err_blob = read_ptr($err_addr);
        if ($err_blob) {
            my $err_ptr = blob_ptr($err_blob);
            my $err_size = blob_size($err_blob);
            if ($err_ptr && $err_size) {
                my $msg = read_mem($err_ptr, $err_size);
                debug_print("D3DCompile error: $msg");
            }
            com_call_0($err_blob, IUnknown_Release);
        }
        die sprintf("D3DCompile failed: 0x%08X\n", $hr & 0xFFFFFFFF);
    }

    my $code_blob = read_ptr($code_addr);
    return $code_blob;
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
    
    # Use FFI::Platypus to call the thunk directly
    my $func = $ffi->function($thunk_mem => [] => 'uint32');
    debug_print("Thunk function created at: " . sprintf("0x%X", $thunk_mem)) unless $debug_in_render;
    
    my $result;
    eval {
        debug_print("Before thunk call") unless $debug_in_render;
        $result = $func->call();
        debug_print("After thunk call, result: " . sprintf("0x%08X", $result & 0xFFFFFFFF)) unless $debug_in_render;
    };
    if ($@) {
        debug_print("Thunk call exception: $@");
        die "Thunk call failed: $@\n";
    }
    return $result;
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
my $g_command_queue;
my $g_command_allocator;
my $g_command_list;
my $g_swap_chain;
my $g_descriptor_heap;
my $g_rtv_descriptor_size = 0;
my $g_rtv_handle_start = 0;
my $g_rtv_handle_addr = 0;
my $g_color_addr = 0;
my $g_barrier_addr = 0;
my $g_cmd_list_addr = 0;
my $g_vb_view_addr = 0;
my $g_viewport_addr = 0;
my $g_scissor_addr = 0;
my $g_root_signature;
my $g_pso;
my $g_fence;
my $g_fence_event;
my $g_fence_value = 1;
my $g_frame_index = 0;
my @g_render_targets = ();
my $g_vertex_buffer;

my $SHADER_CODE = 0;  # Simplified - compiled shader bytecode placeholder

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

sub com_call_0_ptr {
    my ($obj, $vtbl_index) = @_;
    my $vtbl = read_ptr($obj);
    my $func_addr = read_ptr($vtbl + $vtbl_index * 8);

    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $obj);
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');

    return call_thunk_ptr($code);
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

sub com_call_4 {
    my ($obj, $vtbl_index, $arg1, $arg2, $arg3, $arg4) = @_;
    my $vtbl = read_ptr($obj);
    my $func_addr = read_ptr($vtbl + $vtbl_index * 8);

    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $obj);
    $code .= pack('H*', '48BA') . pack('Q', $arg1);
    $code .= pack('H*', '49B8') . pack('Q', $arg2);
    $code .= pack('H*', '49B9') . pack('Q', $arg3);
    $code .= pack('H*', '48B8') . pack('Q', $arg4);
    $code .= pack('H*', '4889442420');
    $code .= pack('H*', '48B8') . pack('Q', $func_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');

    return call_thunk($code);
}

# ============================================================
# Vertex data structure
# ============================================================
# Vertex: position (3 floats) + color (4 floats) = 28 bytes
my @VERTICES = (
    { pos => [0.0, 0.5, 0.0], col => [1.0, 0.0, 0.0, 1.0] },
    { pos => [0.5, -0.5, 0.0], col => [0.0, 1.0, 0.0, 1.0] },
    { pos => [-0.5, -0.5, 0.0], col => [0.0, 0.0, 1.0, 1.0] },
);

my $VERTEX_BUFFER_SIZE = 3 * 28;  # 3 vertices, 28 bytes each

# ============================================================
# DirectX12 initialization
# ============================================================
sub init_d3d {
    debug_print("DirectX 12 initialization starting...");
    
    # Load required DLLs
    my $d3d12_str = encode_utf16("d3d12.dll");
    my $hD3D12 = $LoadLibraryW->Call($d3d12_str);
    die "LoadLibraryW(d3d12.dll) failed\n" unless $hD3D12;
    debug_print("d3d12.dll loaded: " . sprintf("0x%X", $hD3D12));
    
    my $dxgi_str = encode_utf16("dxgi.dll");
    my $hDXGI = $LoadLibraryW->Call($dxgi_str);
    die "LoadLibraryW(dxgi.dll) failed\n" unless $hDXGI;
    debug_print("dxgi.dll loaded: " . sprintf("0x%X", $hDXGI));
    
    # Get factory creation function
    my $CreateDXGIFactory2 = $GetProcAddress->Call($hDXGI, "CreateDXGIFactory2\0");
    die "GetProcAddress(CreateDXGIFactory2) failed\n" unless $CreateDXGIFactory2;
    debug_print("CreateDXGIFactory2 function: " . sprintf("0x%X", $CreateDXGIFactory2));
    
    my $D3D12CreateDevice = $GetProcAddress->Call($hD3D12, "D3D12CreateDevice\0");
    die "GetProcAddress(D3D12CreateDevice) failed\n" unless $D3D12CreateDevice;
    debug_print("D3D12CreateDevice function: " . sprintf("0x%X", $D3D12CreateDevice));
    
    # Create DXGI Factory
    debug_print("Creating DXGI Factory...");
    # Request IDXGIFactory2 for CreateSwapChainForHwnd
    my $factory_iid = guid_from_string("{50c83a1c-e072-4c48-87b0-3630fa36a6d0}"); # IID_IDXGIFactory2
    my $factory_iid_addr = alloc_work(16);
    write_mem($factory_iid_addr, $factory_iid);
    
    my $factory_addr = alloc_work(8);
    write_mem($factory_addr, "\0" x 8);
    
    # CreateDXGIFactory2(UINT Flags, REFIID riid, void **ppFactory)
    # RCX = Flags, RDX = riid, R8 = ppFactory
    # Stack must be 16-byte aligned before call instruction
    my $code = pack('H*', '4883EC28');                       # sub rsp, 0x28 (40 bytes to maintain 16-byte alignment)
    $code .= pack('H*', '48C7C100000000');                   # rcx = 0 (Flags)
    $code .= pack('H*', '48BA') . pack('Q', $factory_iid_addr);    # rdx = IID address
    $code .= pack('H*', '49B8') . pack('Q', $factory_addr);        # r8 = factory output address
    $code .= pack('H*', '48B8') . pack('Q', $CreateDXGIFactory2);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');                         # add rsp, 0x28
    $code .= pack('H*', 'C3');
    
    debug_print("Calling CreateDXGIFactory2 thunk...");
    my $hr = call_thunk($code);
    debug_print("CreateDXGIFactory2 returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    die sprintf("CreateDXGIFactory2 failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    my $factory = read_ptr($factory_addr);
    debug_print("IDXGIFactory2: " . sprintf("0x%X", $factory));
    
    # Create D3D12 Device
    my $device_iid = guid_from_string("{189819f1-1db6-4b57-be54-1821339b85f7}"); # IID_ID3D12Device
    my $device_iid_addr = alloc_work(16);
    write_mem($device_iid_addr, $device_iid);
    
    my $device_addr = alloc_work(8);
    write_mem($device_addr, "\0" x 8);
    
    debug_print("Calling D3D12CreateDevice thunk...");
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48C7C100000000');                    # rcx = 0 (Adapter = NULL)
    $code .= pack('H*', '48C7C200c00000');                    # rdx = 0xc000 (D3D_FEATURE_LEVEL_12_0)
    $code .= pack('H*', '49B8') . pack('Q', $device_iid_addr);
    $code .= pack('H*', '49B9') . pack('Q', $device_addr);
    $code .= pack('H*', '48B8') . pack('Q', $D3D12CreateDevice);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    debug_print("D3D12CreateDevice returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    die sprintf("D3D12CreateDevice failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_device = read_ptr($device_addr);
    debug_print("ID3D12Device: " . sprintf("0x%X", $g_device));
    
    # Create Command Queue
    debug_print("Creating Command Queue...");
    my $device_vtbl = read_ptr($g_device);
    my $create_queue_addr = read_ptr($device_vtbl + ID3D12Device_CreateCommandQueue * 8);
    
    my $queue_desc_addr = alloc_work(24);
    my $queue_desc = pack('L L L L L L',
        D3D12_COMMAND_LIST_TYPE_DIRECT, # Type
        0,                              # Priority
        D3D12_COMMAND_QUEUE_FLAG_NONE,  # Flags
        0                               # NodeMask
    );
    write_mem($queue_desc_addr, $queue_desc);
    
    my $queue_iid = guid_from_string("{0ec870a6-5d7e-4c22-8cfc-5baae07616ed}"); # IID_ID3D12CommandQueue
    my $queue_iid_addr = alloc_work(16);
    write_mem($queue_iid_addr, $queue_iid);
    
    my $queue_addr = alloc_work(8);
    write_mem($queue_addr, "\0" x 8);
    
    debug_print("Calling CreateCommandQueue thunk...");
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $queue_desc_addr);
    $code .= pack('H*', '49B8') . pack('Q', $queue_iid_addr);
    $code .= pack('H*', '49B9') . pack('Q', $queue_addr);
    $code .= pack('H*', '48B8') . pack('Q', $create_queue_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    debug_print("CreateCommandQueue returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    die sprintf("CreateCommandQueue failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_command_queue = read_ptr($queue_addr);
    debug_print("ID3D12CommandQueue: " . sprintf("0x%X", $g_command_queue));
    
    # Create Fence
    my $create_fence_addr = read_ptr($device_vtbl + ID3D12Device_CreateFence * 8);
    
    my $fence_iid = guid_from_string("{0a753dcf-c4d8-4b91-adf6-be5a60d95a76}"); # IID_ID3D12Fence
    my $fence_iid_addr = alloc_work(16);
    write_mem($fence_iid_addr, $fence_iid);
    
    my $fence_addr = alloc_work(8);
    write_mem($fence_addr, "\0" x 8);
    
    debug_print("Calling CreateFence thunk...");
    # CreateFence signature: HRESULT CreateFence(UINT64 InitialValue, D3D12_FENCE_FLAGS Flags, REFIID riid, void **ppFence)
    # Parameters: RCX=Device, RDX=InitialValue, R8=Flags, R9=riid, [RSP+0x20]=ppFence
    $code = pack('H*', '4883EC28');                         # sub rsp, 0x28
    $code .= pack('H*', '48B9') . pack('Q', $g_device);    # mov rcx, device
    $code .= pack('H*', '48BA') . pack('Q', 0);            # mov rdx, 0 (InitialValue)
    $code .= pack('H*', '41C7C000000000');                 # mov r8d, 0 (Flags)
    $code .= pack('H*', '49B9') . pack('Q', $fence_iid_addr);  # mov r9, riid
    $code .= pack('H*', '48B8') . pack('Q', $fence_addr);  # mov rax, ppFence address
    $code .= pack('H*', '4889442420');                     # mov [rsp + 0x20], rax
    $code .= pack('H*', '48B8') . pack('Q', $create_fence_addr);  # mov rax, func_addr
    $code .= pack('H*', 'FFD0');                           # call rax
    $code .= pack('H*', '4883C428');                       # add rsp, 0x28
    $code .= pack('H*', 'C3');                             # ret
    
    $hr = call_thunk($code);
    debug_print("CreateFence returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    # Allow 0x00000001 as well as S_OK (some versions may return 0x00000001)
    die sprintf("CreateFence failed: 0x%08X\n", $hr & 0xFFFFFFFF) if ($hr & 0xFFFFFFFF) > 1;
    
    $g_fence = read_ptr($fence_addr);
    debug_print("ID3D12Fence: " . sprintf("0x%X", $g_fence));

    $g_fence_event = $CreateEventA->Call(0, 0, 0, 0);
    die "CreateEventA failed for fence event\n" unless $g_fence_event;
    $g_fence_value = 1;
    
    # Create swap chain (IDXGIFactory2::CreateSwapChainForHwnd)
    debug_print("Creating Swap Chain (ForHwnd)...");
    my $factory_vtbl = read_ptr($factory);
    my $create_swap_addr = read_ptr($factory_vtbl + IDXGIFactory2_CreateSwapChainForHwnd * 8);
    
    # Create DXGI_SWAP_CHAIN_DESC1 structure (48 bytes)
    my $swap_desc1_addr = alloc_work(48);
    my $swap_desc1 = "";
    $swap_desc1 .= pack('L', 0);                               # Width (0 = use window size)
    $swap_desc1 .= pack('L', 0);                               # Height (0 = use window size)
    $swap_desc1 .= pack('L', DXGI_FORMAT_R8G8B8A8_UNORM);    # Format
    $swap_desc1 .= pack('L', 0);                              # Stereo (FALSE)
    $swap_desc1 .= pack('L', 1);                              # SampleDesc.Count
    $swap_desc1 .= pack('L', 0);                              # SampleDesc.Quality
    $swap_desc1 .= pack('L', DXGI_USAGE_RENDER_TARGET_OUTPUT); # BufferUsage
    $swap_desc1 .= pack('L', FRAMES);                         # BufferCount
    $swap_desc1 .= pack('L', DXGI_SCALING_STRETCH);          # Scaling
    $swap_desc1 .= pack('L', DXGI_SWAP_EFFECT_FLIP_DISCARD); # SwapEffect
    $swap_desc1 .= pack('L', DXGI_ALPHA_MODE_UNSPECIFIED);   # AlphaMode
    $swap_desc1 .= pack('L', 0);                              # Flags
    
    write_mem($swap_desc1_addr, $swap_desc1);
    
    my $swap_addr = alloc_work(8);
    write_mem($swap_addr, "\0" x 8);
    
    debug_print("Calling CreateSwapChainForHwnd thunk...");
    # CreateSwapChainForHwnd(factory, queue, hwnd, desc1, fullscreenDesc, restrictToOutput, ppSwapChain)
    # Stack: shadow space (0x20) + 3 stack args (0x18) + padding (0x8) = 0x48
    $code = pack('H*', '4883EC48');
    $code .= pack('H*', '48B9') . pack('Q', $factory);
    $code .= pack('H*', '48BA') . pack('Q', $g_command_queue);
    $code .= pack('H*', '49B8') . pack('Q', $hwnd);
    $code .= pack('H*', '49B9') . pack('Q', $swap_desc1_addr);
    $code .= pack('H*', '31C0');                             # xor eax, eax (NULL)
    $code .= pack('H*', '4889442420');                       # [rsp+0x20] = fullscreenDesc (NULL)
    $code .= pack('H*', '4889442428');                       # [rsp+0x28] = restrictToOutput (NULL)
    $code .= pack('H*', '48B8') . pack('Q', $swap_addr);      # rax = &ppSwapChain
    $code .= pack('H*', '4889442430');                       # [rsp+0x30] = ppSwapChain
    $code .= pack('H*', '48B8') . pack('Q', $create_swap_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C448');
    $code .= pack('H*', 'C3');
    
    $hr = call_thunk($code);
    debug_print("CreateSwapChainForHwnd returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    die sprintf("CreateSwapChainForHwnd failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    
    $g_swap_chain = read_ptr($swap_addr);
    debug_print("IDXGISwapChain: " . sprintf("0x%X", $g_swap_chain));

    # Create RTV descriptor heap
    my $create_rtv_heap_addr = read_ptr($device_vtbl + ID3D12Device_CreateDescriptorHeap * 8);
    my $rtv_heap_desc_addr = alloc_work(16);
    my $rtv_heap_desc = pack('L L L L',
        D3D12_DESCRIPTOR_HEAP_TYPE_RTV, # Type
        FRAMES,                          # NumDescriptors
        D3D12_DESCRIPTOR_HEAP_FLAG_NONE, # Flags
        0                                # NodeMask
    );
    write_mem($rtv_heap_desc_addr, $rtv_heap_desc);

    my $rtv_heap_iid = guid_from_string("{8efb471d-616c-4f49-90f7-127bb763fa51}"); # IID_ID3D12DescriptorHeap
    my $rtv_heap_iid_addr = alloc_work(16);
    write_mem($rtv_heap_iid_addr, $rtv_heap_iid);

    my $rtv_heap_addr = alloc_work(8);
    write_mem($rtv_heap_addr, "\0" x 8);

    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $rtv_heap_desc_addr);
    $code .= pack('H*', '49B8') . pack('Q', $rtv_heap_iid_addr);
    $code .= pack('H*', '49B9') . pack('Q', $rtv_heap_addr);
    $code .= pack('H*', '48B8') . pack('Q', $create_rtv_heap_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');

    $hr = call_thunk($code);
    debug_print("CreateDescriptorHeap returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    die sprintf("CreateDescriptorHeap failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;

    $g_descriptor_heap = read_ptr($rtv_heap_addr);
    $g_rtv_descriptor_size = com_call_1($g_device, ID3D12Device_GetDescriptorHandleIncrementSize, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    debug_print("RTV descriptor size: " . sprintf("0x%X", $g_rtv_descriptor_size));
    debug_print("Calling GetCPUDescriptorHandleForHeapStart...");
    my $heap_vtbl = read_ptr($g_descriptor_heap);
    my $get_handle_addr = read_ptr($heap_vtbl + ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart * 8);
    debug_print("GetCPUDescriptorHandleForHeapStart addr: " . sprintf("0x%X", $get_handle_addr));

    my $handle_addr = alloc_work(8);
    write_mem($handle_addr, "\0" x 8);

    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_descriptor_heap);
    $code .= pack('H*', '48BA') . pack('Q', $handle_addr);
    $code .= pack('H*', '48B8') . pack('Q', $get_handle_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');

    call_thunk($code);
    $g_rtv_handle_start = read_ptr($handle_addr);
    debug_print("RTV handle start: " . sprintf("0x%X", $g_rtv_handle_start));
    die "GetCPUDescriptorHandleForHeapStart returned null handle\n" unless $g_rtv_handle_start;

    # Create render target views for each back buffer
    my $resource_iid = guid_from_string("{696442be-a72e-4059-bc79-5b5c98040fad}"); # IID_ID3D12Resource
    my $resource_iid_addr = alloc_work(16);
    write_mem($resource_iid_addr, $resource_iid);

    for (my $i = 0; $i < FRAMES; $i++) {
        my $rt_addr = alloc_work(8);
        write_mem($rt_addr, "\0" x 8);

        my $get_buffer_addr = read_ptr(read_ptr($g_swap_chain) + IDXGISwapChain_GetBuffer * 8);
        debug_print("GetBuffer(" . $i . ") call...");
        $code = pack('H*', '4883EC38');
        $code .= pack('H*', '48B9') . pack('Q', $g_swap_chain);
        $code .= pack('H*', '48BA') . pack('Q', $i);
        $code .= pack('H*', '49B8') . pack('Q', $resource_iid_addr);
        $code .= pack('H*', '49B9') . pack('Q', $rt_addr);
        $code .= pack('H*', '48B8') . pack('Q', $get_buffer_addr);
        $code .= pack('H*', 'FFD0');
        $code .= pack('H*', '4883C438');
        $code .= pack('H*', 'C3');

        $hr = call_thunk($code);
        debug_print("GetBuffer(" . $i . ") returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
        die sprintf("GetBuffer(%d) failed: 0x%08X\n", $i, $hr & 0xFFFFFFFF) if $hr != S_OK;

        my $rt = read_ptr($rt_addr);
        $g_render_targets[$i] = $rt;

        my $rtv_handle = $g_rtv_handle_start + ($i * $g_rtv_descriptor_size);
        debug_print("CreateRenderTargetView(" . $i . ")...");
        com_call_3($g_device, ID3D12Device_CreateRenderTargetView, $rt, 0, $rtv_handle);
        debug_print("CreateRenderTargetView(" . $i . ") done");
    }

    # Create Command Allocator
    my $create_allocator_addr = read_ptr($device_vtbl + ID3D12Device_CreateCommandAllocator * 8);
    my $allocator_iid = guid_from_string("{6102dee4-af59-4b09-b999-b44d73f09b24}"); # IID_ID3D12CommandAllocator
    my $allocator_iid_addr = alloc_work(16);
    write_mem($allocator_iid_addr, $allocator_iid);

    my $allocator_addr = alloc_work(8);
    write_mem($allocator_addr, "\0" x 8);

    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', D3D12_COMMAND_LIST_TYPE_DIRECT);
    $code .= pack('H*', '49B8') . pack('Q', $allocator_iid_addr);
    $code .= pack('H*', '49B9') . pack('Q', $allocator_addr);
    $code .= pack('H*', '48B8') . pack('Q', $create_allocator_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');

    $hr = call_thunk($code);
    debug_print("CreateCommandAllocator returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    die sprintf("CreateCommandAllocator failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    $g_command_allocator = read_ptr($allocator_addr);
    debug_print("ID3D12CommandAllocator: " . sprintf("0x%X", $g_command_allocator));

    # Create Command List
    my $create_list_addr = read_ptr($device_vtbl + ID3D12Device_CreateCommandList * 8);
    my $list_iid = guid_from_string("{5b160d0f-ac1b-4185-8ba8-b3ae42a5a455}"); # IID_ID3D12GraphicsCommandList
    my $list_iid_addr = alloc_work(16);
    write_mem($list_iid_addr, $list_iid);

    my $list_addr = alloc_work(8);
    write_mem($list_addr, "\0" x 8);

    $code = pack('H*', '4883EC48');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', 0);                               # nodeMask
    $code .= pack('H*', '49B8') . pack('Q', D3D12_COMMAND_LIST_TYPE_DIRECT);   # type
    $code .= pack('H*', '49B9') . pack('Q', $g_command_allocator);             # allocator
    $code .= pack('H*', '48C7C000000000');                                    # rax = 0 (initialState)
    $code .= pack('H*', '4889442420');                                        # [rsp+0x20] = initialState
    $code .= pack('H*', '48B8') . pack('Q', $list_iid_addr);                  # rax = &IID
    $code .= pack('H*', '4889442428');                                        # [rsp+0x28] = riid
    $code .= pack('H*', '48B8') . pack('Q', $list_addr);                      # rax = &ppList
    $code .= pack('H*', '4889442430');                                        # [rsp+0x30] = ppList
    $code .= pack('H*', '48B8') . pack('Q', $create_list_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C448');
    $code .= pack('H*', 'C3');

    $hr = call_thunk($code);
    debug_print("CreateCommandList returned: " . sprintf("0x%08X", $hr & 0xFFFFFFFF));
    die sprintf("CreateCommandList failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    $g_command_list = read_ptr($list_addr);
    debug_print("ID3D12GraphicsCommandList: " . sprintf("0x%X", $g_command_list));

    com_call_0($g_command_list, ID3D12GraphicsCommandList_Close);

    debug_print("Starting root signature creation...");

    # Create Root Signature
    my $rs_desc_addr = alloc_work(40);
    my $rs_desc = pack('L x4 Q L x4 Q L x4',
        0, 0, 0, 0, D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
    );
    write_mem($rs_desc_addr, $rs_desc);

    my $sig_addr = alloc_work(8);
    write_mem($sig_addr, "\0" x 8);
    my $sig_err_addr = alloc_work(8);
    write_mem($sig_err_addr, "\0" x 8);

    my $serialize_rs_addr = $GetProcAddress->Call($hD3D12, "D3D12SerializeRootSignature\0");
    die "GetProcAddress(D3D12SerializeRootSignature) failed\n" unless $serialize_rs_addr;

    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $rs_desc_addr);
    $code .= pack('H*', '48BA') . pack('Q', D3D_ROOT_SIGNATURE_VERSION_1);
    $code .= pack('H*', '49B8') . pack('Q', $sig_addr);
    $code .= pack('H*', '49B9') . pack('Q', $sig_err_addr);
    $code .= pack('H*', '48B8') . pack('Q', $serialize_rs_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');

    $hr = call_thunk($code);
    if ($hr != S_OK) {
        my $err_blob = read_ptr($sig_err_addr);
        if ($err_blob) {
            my $err_ptr = blob_ptr($err_blob);
            my $err_size = blob_size($err_blob);
            if ($err_ptr && $err_size) {
                my $msg = read_mem($err_ptr, $err_size);
                debug_print("Root signature error: $msg");
            }
            com_call_0($err_blob, IUnknown_Release);
        }
        die sprintf("D3D12SerializeRootSignature failed: 0x%08X\n", $hr & 0xFFFFFFFF);
    }

    debug_print("Root signature blob created");

    my $sig_blob = read_ptr($sig_addr);
    my $sig_ptr = blob_ptr($sig_blob);
    my $sig_size = blob_size($sig_blob);

    my $root_iid = guid_from_string("{c54a6b66-72df-4ee8-8be5-a946a1429214}"); # IID_ID3D12RootSignature
    my $root_iid_addr = alloc_work(16);
    write_mem($root_iid_addr, $root_iid);
    my $root_addr = alloc_work(8);
    write_mem($root_addr, "\0" x 8);

    my $create_root_addr = read_ptr($device_vtbl + ID3D12Device_CreateRootSignature * 8);
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', 0);               # nodeMask
    $code .= pack('H*', '49B8') . pack('Q', $sig_ptr);
    $code .= pack('H*', '49B9') . pack('Q', $sig_size);
    $code .= pack('H*', '48B8') . pack('Q', $root_iid_addr);
    $code .= pack('H*', '4889442420');                        # [rsp+0x20] = riid
    $code .= pack('H*', '48B8') . pack('Q', $root_addr);
    $code .= pack('H*', '4889442428');                        # [rsp+0x28] = ppv
    $code .= pack('H*', '48B8') . pack('Q', $create_root_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');

    $hr = call_thunk($code);
    die sprintf("CreateRootSignature failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    $g_root_signature = read_ptr($root_addr);

    debug_print("Root signature created");

    com_call_0($sig_blob, IUnknown_Release);

    # Compile shaders
    debug_print("Compiling shaders...");
    my $vs_blob = compile_hlsl("VS", "vs_5_0");
    my $ps_blob = compile_hlsl("PS", "ps_5_0");
    debug_print("Shaders compiled");

    # Input layout
    my $pos_sem = "POSITION\0";
    my $pos_sem_addr = alloc_work(length($pos_sem));
    write_mem($pos_sem_addr, $pos_sem);
    my $col_sem = "COLOR\0";
    my $col_sem_addr = alloc_work(length($col_sem));
    write_mem($col_sem_addr, $col_sem);

    my $input_elem_addr = alloc_work(32 * 2);
    my $ie0 = pack('Q L L L L L L',
        $pos_sem_addr, 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0,
        D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0
    );
    my $ie1 = pack('Q L L L L L L',
        $col_sem_addr, 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12,
        D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0
    );
    write_mem($input_elem_addr, $ie0 . $ie1);

    my $input_layout = pack('Q L x4', $input_elem_addr, 2);

    # Blend state
    my $rt_blend = pack('L L L L L L L L L C x3',
        0, 0, D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
        D3D12_BLEND_ONE, D3D12_BLEND_ZERO, D3D12_BLEND_OP_ADD,
        D3D12_LOGIC_OP_NOOP, D3D12_COLOR_WRITE_ENABLE_ALL
    );
    my $blend_desc = pack('L L', 0, 0) . $rt_blend . ("\0" x (40 * 7));

    # Rasterizer state
    my $raster_desc = pack('L L L l f f L L L L L',
        D3D12_FILL_MODE_SOLID, D3D12_CULL_MODE_NONE, 0, 0,
        0.0, 0.0, 1, 0, 0, 0, 0
    );

    # Depth stencil state (disabled)
    my $depth_desc = pack('L L L L C C x2 L L L L L L L L',
        0, D3D12_DEPTH_WRITE_MASK_ALL, D3D12_COMPARISON_FUNC_LESS, 0,
        0, 0,
        D3D12_STENCIL_OP_KEEP, D3D12_STENCIL_OP_KEEP, D3D12_STENCIL_OP_KEEP, 8,
        D3D12_STENCIL_OP_KEEP, D3D12_STENCIL_OP_KEEP, D3D12_STENCIL_OP_KEEP, 8
    );

    # PSO
    my $pso_desc = "";
    $pso_desc .= pack('Q', $g_root_signature);
    $pso_desc .= pack('Q Q', blob_ptr($vs_blob), blob_size($vs_blob));
    $pso_desc .= pack('Q Q', blob_ptr($ps_blob), blob_size($ps_blob));
    $pso_desc .= "\0" x (16 * 3); # DS/HS/GS
    $pso_desc .= pack('Q L x4 Q L L', 0, 0, 0, 0, 0); # StreamOutput
    $pso_desc .= $blend_desc;
    $pso_desc .= pack('L', 0xFFFFFFFF); # SampleMask
    $pso_desc .= $raster_desc;
    $pso_desc .= $depth_desc;
    $pso_desc .= "\0" x 4; # padding to 8
    $pso_desc .= $input_layout;
    $pso_desc .= pack('L', 0); # IBStripCutValue
    $pso_desc .= pack('L', D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE);
    $pso_desc .= pack('L', 1); # NumRenderTargets
    $pso_desc .= pack('L8', DXGI_FORMAT_R8G8B8A8_UNORM, 0, 0, 0, 0, 0, 0, 0);
    $pso_desc .= pack('L', 0); # DSVFormat
    $pso_desc .= pack('L L', 1, 0); # SampleDesc
    $pso_desc .= pack('L', 0); # NodeMask
    $pso_desc .= pack('Q Q', 0, 0); # CachedPSO
    $pso_desc .= pack('L', D3D12_PIPELINE_STATE_FLAG_NONE);
    $pso_desc .= "\0" x 4;

    my $pso_desc_addr = alloc_work(length($pso_desc));
    write_mem($pso_desc_addr, $pso_desc);

    my $pso_iid = guid_from_string("{765a30f3-f624-4c6f-a828-ace948622445}"); # IID_ID3D12PipelineState
    my $pso_iid_addr = alloc_work(16);
    write_mem($pso_iid_addr, $pso_iid);
    my $pso_addr = alloc_work(8);
    write_mem($pso_addr, "\0" x 8);

    my $create_pso_addr = read_ptr($device_vtbl + ID3D12Device_CreateGraphicsPipelineState * 8);
    $code = pack('H*', '4883EC38');
    $code .= pack('H*', '48B9') . pack('Q', $g_device);
    $code .= pack('H*', '48BA') . pack('Q', $pso_desc_addr);
    $code .= pack('H*', '49B8') . pack('Q', $pso_iid_addr);
    $code .= pack('H*', '49B9') . pack('Q', $pso_addr);
    $code .= pack('H*', '48B8') . pack('Q', $create_pso_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C438');
    $code .= pack('H*', 'C3');

    $hr = call_thunk($code);
    die sprintf("CreateGraphicsPipelineState failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    $g_pso = read_ptr($pso_addr);

    debug_print("Pipeline state created");

    debug_print("Releasing shader blobs...");
    com_call_0($vs_blob, IUnknown_Release);
    com_call_0($ps_blob, IUnknown_Release);

    # Create vertex buffer
    debug_print("Creating vertex buffer...");
    my $vb_size = $VERTEX_BUFFER_SIZE;
    my $heap_props = pack('L L L L L', D3D12_HEAP_TYPE_UPLOAD, 0, 0, 1, 1);
    my $heap_props_addr = alloc_work(length($heap_props));
    write_mem($heap_props_addr, $heap_props);

    my $res_desc = pack('L x4 Q Q L S S L L L L',
        D3D12_RESOURCE_DIMENSION_BUFFER, 0, $vb_size, 1,
        1, 1, 0, 1, 0, D3D12_TEXTURE_LAYOUT_ROW_MAJOR, D3D12_RESOURCE_FLAG_NONE
    );
    my $res_desc_addr = alloc_work(length($res_desc));
    write_mem($res_desc_addr, $res_desc);

    my $vb_addr = alloc_work(8);
    write_mem($vb_addr, "\0" x 8);
    my $res_iid = guid_from_string("{696442be-a72e-4059-bc79-5b5c98040fad}"); # IID_ID3D12Resource
    my $res_iid_addr = alloc_work(16);
    write_mem($res_iid_addr, $res_iid);

    my $create_res_addr = read_ptr($device_vtbl + ID3D12Device_CreateCommittedResource * 8);
    my $create_res = $ffi->function($create_res_addr => [
        'opaque',  # this
        'opaque',  # pHeapProperties
        'uint32',  # HeapFlags
        'opaque',  # pDesc
        'uint32',  # InitialResourceState
        'opaque',  # pOptimizedClearValue
        'opaque',  # riid
        'opaque'   # ppResource
    ] => 'uint32');

    $hr = $create_res->call(
        $g_device,
        $heap_props_addr,
        0,
        $res_desc_addr,
        D3D12_RESOURCE_STATE_GENERIC_READ,
        0,
        $res_iid_addr,
        $vb_addr
    );
    die sprintf("CreateCommittedResource failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    $g_vertex_buffer = read_ptr($vb_addr);

    debug_print("Vertex buffer created");

    # Map and copy vertex data
    debug_print("Mapping vertex buffer...");
    my $map_addr = read_ptr(read_ptr($g_vertex_buffer) + ID3D12Resource_Map * 8);
    my $range_addr = alloc_work(16);
    write_mem($range_addr, pack('Q Q', 0, 0));
    my $data_addr = alloc_work(8);
    write_mem($data_addr, "\0" x 8);

    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_vertex_buffer);
    $code .= pack('H*', '48BA') . pack('Q', 0);
    $code .= pack('H*', '49B8') . pack('Q', $range_addr);
    $code .= pack('H*', '49B9') . pack('Q', $data_addr);
    $code .= pack('H*', '48B8') . pack('Q', $map_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    $hr = call_thunk($code);
    die sprintf("Map failed: 0x%08X\n", $hr & 0xFFFFFFFF) if $hr != S_OK;
    debug_print("Vertex buffer mapped");

    my $vb_ptr = read_ptr($data_addr);
    my $vb_data = "";
    for my $v (@VERTICES) {
        $vb_data .= pack('f3', @{$v->{pos}});
        $vb_data .= pack('f4', @{$v->{col}});
    }
    write_mem($vb_ptr, $vb_data);
    com_call_2($g_vertex_buffer, ID3D12Resource_Unmap, 0, 0);

    debug_print("Vertex buffer data uploaded");

    my $gpu_addr = com_call_0_ptr($g_vertex_buffer, ID3D12Resource_GetGPUVirtualAddress);
    $g_vb_view_addr = alloc_work(16);
    write_mem($g_vb_view_addr, pack('Q L L', $gpu_addr, $vb_size, 28));

    # Viewport/scissor
    $g_viewport_addr = alloc_work(24);
    write_mem($g_viewport_addr, pack('f6', 0.0, 0.0, 640.0, 480.0, 0.0, 1.0));
    $g_scissor_addr = alloc_work(16);
    write_mem($g_scissor_addr, pack('l4', 0, 0, 640, 480));

    # Scratch buffers for render
    $g_rtv_handle_addr = alloc_work(8);
    $g_color_addr = alloc_work(16);
    write_mem($g_color_addr, pack('f4', 0.1, 0.1, 0.3, 1.0));
    $g_barrier_addr = alloc_work(32);
    $g_cmd_list_addr = alloc_work(8);
    
    debug_print("DirectX 12 device initialized (basic setup complete)");
}

# ============================================================
# Render
# ============================================================
sub render {
    return unless $g_command_list && $g_command_allocator && $g_command_queue && $g_swap_chain;

    $debug_in_render = 1;

    com_call_0($g_command_allocator, ID3D12CommandAllocator_Reset);
    com_call_2($g_command_list, ID3D12GraphicsCommandList_Reset, $g_command_allocator, $g_pso);

    com_call_1($g_command_list, ID3D12GraphicsCommandList_SetPipelineState, $g_pso);
    com_call_1($g_command_list, ID3D12GraphicsCommandList_SetGraphicsRootSignature, $g_root_signature);
    com_call_2($g_command_list, ID3D12GraphicsCommandList_RSSetViewports, 1, $g_viewport_addr);
    com_call_2($g_command_list, ID3D12GraphicsCommandList_RSSetScissorRects, 1, $g_scissor_addr);
    com_call_1($g_command_list, ID3D12GraphicsCommandList_IASetPrimitiveTopology, D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    com_call_3($g_command_list, ID3D12GraphicsCommandList_IASetVertexBuffers, 0, 1, $g_vb_view_addr);

    my $rt = $g_render_targets[$g_frame_index];
    return unless $rt;

    my $rtv_handle = $g_rtv_handle_start + ($g_frame_index * $g_rtv_descriptor_size);
    write_mem($g_rtv_handle_addr, pack('Q', $rtv_handle));

    # Transition to render target
    my $barrier = pack('L L Q L L L L',
        D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
        D3D12_RESOURCE_BARRIER_FLAG_NONE,
        $rt,
        D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
        D3D12_RESOURCE_STATE_PRESENT,
        D3D12_RESOURCE_STATE_RENDER_TARGET,
        0
    );
    write_mem($g_barrier_addr, $barrier);
    com_call_2($g_command_list, ID3D12GraphicsCommandList_ResourceBarrier, 1, $g_barrier_addr);

    # OMSetRenderTargets
    my $cl_vtbl = read_ptr($g_command_list);
    my $om_addr = read_ptr($cl_vtbl + ID3D12GraphicsCommandList_OMSetRenderTargets * 8);
    my $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_command_list);
    $code .= pack('H*', '48BA') . pack('Q', 1);
    $code .= pack('H*', '49B8') . pack('Q', $g_rtv_handle_addr);
    $code .= pack('H*', '49B9') . pack('Q', 1);
    $code .= pack('H*', '48C7C000000000');
    $code .= pack('H*', '4889442420');
    $code .= pack('H*', '48B8') . pack('Q', $om_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    call_thunk($code);

    # ClearRenderTargetView
    my $clear_addr = read_ptr($cl_vtbl + ID3D12GraphicsCommandList_ClearRenderTargetView * 8);
    $code = pack('H*', '4883EC28');
    $code .= pack('H*', '48B9') . pack('Q', $g_command_list);
    $code .= pack('H*', '48BA') . pack('Q', $rtv_handle);
    $code .= pack('H*', '49B8') . pack('Q', $g_color_addr);
    $code .= pack('H*', '49B9') . pack('Q', 0);
    $code .= pack('H*', '48C7C000000000');
    $code .= pack('H*', '4889442420');
    $code .= pack('H*', '48B8') . pack('Q', $clear_addr);
    $code .= pack('H*', 'FFD0');
    $code .= pack('H*', '4883C428');
    $code .= pack('H*', 'C3');
    call_thunk($code);

    com_call_4($g_command_list, ID3D12GraphicsCommandList_DrawInstanced, 3, 1, 0, 0);

    # Transition back to present
    $barrier = pack('L L Q L L L L',
        D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
        D3D12_RESOURCE_BARRIER_FLAG_NONE,
        $rt,
        D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
        D3D12_RESOURCE_STATE_RENDER_TARGET,
        D3D12_RESOURCE_STATE_PRESENT,
        0
    );
    write_mem($g_barrier_addr, $barrier);
    com_call_2($g_command_list, ID3D12GraphicsCommandList_ResourceBarrier, 1, $g_barrier_addr);

    com_call_0($g_command_list, ID3D12GraphicsCommandList_Close);

    write_mem($g_cmd_list_addr, pack('Q', $g_command_list));
    com_call_2($g_command_queue, ID3D12CommandQueue_ExecuteCommandLists, 1, $g_cmd_list_addr);
    com_call_2($g_swap_chain, IDXGISwapChain_Present, 1, 0);

    if ($g_fence && $g_fence_event) {
        com_call_2($g_command_queue, ID3D12CommandQueue_Signal, $g_fence, $g_fence_value);
        my $completed = com_call_0_ptr($g_fence, ID3D12Fence_GetCompletedValue);
        if ($completed < $g_fence_value) {
            com_call_2($g_fence, ID3D12Fence_SetEventOnCompletion, $g_fence_value, $g_fence_event);
            $WaitForSingleObject->Call($g_fence_event, 0xFFFFFFFF);
        }
        $g_fence_value++;
    }

    $g_frame_index = ($g_frame_index + 1) % FRAMES;

    $debug_in_render = 0;
}

# ============================================================
# Cleanup
# ============================================================
sub cleanup {
    for my $rt (@g_render_targets) {
        com_call_0($rt, IUnknown_Release) if $rt;
    }
    com_call_0($g_vertex_buffer, IUnknown_Release) if $g_vertex_buffer;
    com_call_0($g_pso, IUnknown_Release) if $g_pso;
    com_call_0($g_root_signature, IUnknown_Release) if $g_root_signature;
    com_call_0($g_descriptor_heap, IUnknown_Release) if $g_descriptor_heap;
    com_call_0($g_swap_chain, IUnknown_Release) if $g_swap_chain;
    com_call_0($g_fence, IUnknown_Release) if $g_fence;
    com_call_0($g_command_list, IUnknown_Release) if $g_command_list;
    com_call_0($g_command_allocator, IUnknown_Release) if $g_command_allocator;
    com_call_0($g_command_queue, IUnknown_Release) if $g_command_queue;
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
    
    my $class_name = encode_utf16("PerlD3D12Class");
    my $class_name_ptr = unpack('Q', pack('p', $class_name));
    
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80, CS_HREDRAW | CS_VREDRAW, $defproc_addr,
        0, 0, $hinstance, 0, $hcursor, 0, 0, $class_name_ptr, 0
    );
    
    my $class_atom = $RegisterClassExW->Call($wndclass);
    die sprintf("RegisterClassExW failed: 0x%08X\n", $GetLastError->Call()) unless $class_atom;
    print "Window class registered\n";
    
    my $window_title = encode_utf16("DirectX12 Perl Triangle");
    
    $hwnd = $CreateWindowExW->Call(
        0, $class_name, $window_title, WS_OVERLAPPEDWINDOW,
        100, 100, 640, 480, 0, 0, $hinstance, 0
    );
    die sprintf("CreateWindowExW failed: 0x%08X\n", $GetLastError->Call()) unless $hwnd;
    print "Window created: ", sprintf("0x%X", $hwnd), "\n";
    
    $ShowWindow->Call($hwnd, SW_SHOWNORMAL);
    $UpdateWindow->Call($hwnd);
    print "Window shown\n";
    
    print "\n--- Initializing Direct3D 12 ---\n";
    init_d3d();
    
    print "\n=== DirectX12 Triangle Demo ===\n";
    print "Close the window to exit.\n\n";

    my $msg = "\0" x 48;
    while (1) {
        while ($PeekMessageW->Call($msg, 0, 0, 0, PM_REMOVE)) {
            my $msg_id = unpack('L', substr($msg, 8, 4));
            last if $msg_id == 0x0012; # WM_QUIT
            $TranslateMessage->Call($msg);
            $DispatchMessageW->Call($msg);
        }
        last if unpack('L', substr($msg, 8, 4)) == 0x0012;
        last unless $IsWindow->Call($hwnd);

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
