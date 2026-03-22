#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Win32::API;
use FFI::Platypus 2.00;
use FFI::Platypus::Memory qw(malloc free memcpy);
use FFI::Platypus::Buffer qw(buffer_to_scalar scalar_to_pointer);
use Encode qw(encode);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

# DirectComposition multi-panel sample in Perl.
#
# This script follows the same architecture as the Python and Ruby references:
# - One Win32 host window
# - One shared D3D11 device
# - One DirectComposition root visual
# - Three DXGI composition swap chains
#   Panel 0: OpenGL 4.6 via WGL_NV_DX_interop
#   Panel 1: Direct3D 11 triangle
#   Panel 2: Vulkan offscreen render copied into a D3D11 staging texture

my $PANEL_W  = 320;
my $PANEL_H  = 480;
my $WINDOW_W = $PANEL_W * 3;
my $WINDOW_H = $PANEL_H;
my $SCRIPT_DIR = dirname(abs_path($0));

my $ffi = FFI::Platypus->new(api => 2);
$ffi->lib(undef);

use constant {
    WS_OVERLAPPEDWINDOW => 0x00CF0000,
    CS_OWNDC            => 0x0020,
    CW_USEDEFAULT       => 0x80000000,
    SW_SHOW             => 5,
    WM_QUIT             => 0x0012,
    PM_REMOVE           => 0x0001,

    PFD_TYPE_RGBA       => 0,
    PFD_MAIN_PLANE      => 0,
    PFD_DRAW_TO_WINDOW  => 0x00000004,
    PFD_SUPPORT_OPENGL  => 0x00000020,
    PFD_DOUBLEBUFFER    => 0x00000001,

    GL_COLOR_BUFFER_BIT => 0x00004000,
    GL_TRIANGLES        => 0x0004,
    GL_FALSE            => 0,
    GL_FLOAT            => 0x1406,
    GL_ARRAY_BUFFER     => 0x8892,
    GL_STATIC_DRAW      => 0x88E4,
    GL_VERTEX_SHADER    => 0x8B31,
    GL_FRAGMENT_SHADER  => 0x8B30,
    GL_COMPILE_STATUS   => 0x8B81,
    GL_LINK_STATUS      => 0x8B82,
    GL_INFO_LOG_LENGTH  => 0x8B84,
    GL_VERSION          => 0x1F02,
    GL_SHADING_LANGUAGE_VERSION => 0x8B8C,
    GL_FRAMEBUFFER      => 0x8D40,
    GL_RENDERBUFFER     => 0x8D41,
    GL_COLOR_ATTACHMENT0 => 0x8CE0,

    WGL_CONTEXT_MAJOR_VERSION_ARB    => 0x2091,
    WGL_CONTEXT_MINOR_VERSION_ARB    => 0x2092,
    WGL_CONTEXT_PROFILE_MASK_ARB     => 0x9126,
    WGL_CONTEXT_CORE_PROFILE_BIT_ARB => 0x00000001,
    WGL_ACCESS_READ_WRITE_NV         => 0x0001,

    D3D11_SDK_VERSION                => 7,
    D3D_DRIVER_TYPE_HARDWARE         => 1,
    D3D_FEATURE_LEVEL_11_0           => 0xB000,
    D3D11_CREATE_DEVICE_BGRA_SUPPORT => 0x20,
    D3D11_USAGE_STAGING              => 3,
    D3D11_CPU_ACCESS_WRITE           => 0x00010000,
    D3D11_MAP_WRITE                  => 2,

    DXGI_FORMAT_B8G8R8A8_UNORM       => 87,
    DXGI_USAGE_RENDER_TARGET_OUTPUT  => 0x20,
    DXGI_SCALING_STRETCH             => 0,
    DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL => 3,
    DXGI_ALPHA_MODE_PREMULTIPLIED    => 1,
    DXGI_ALPHA_MODE_IGNORE           => 3,

    VK_SUCCESS                                   => 0,
    VK_STRUCTURE_TYPE_APPLICATION_INFO           => 0,
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO       => 1,
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO   => 2,
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO         => 3,
    VK_STRUCTURE_TYPE_SUBMIT_INFO                => 4,
    VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO       => 5,
    VK_STRUCTURE_TYPE_FENCE_CREATE_INFO          => 8,
    VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO         => 12,
    VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO          => 14,
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO     => 15,
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO  => 16,
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO => 18,
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO => 19,
    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO => 20,
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO => 22,
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO => 23,
    VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO => 24,
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO => 26,
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO => 28,
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO => 30,
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO    => 37,
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO    => 38,
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO   => 39,
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO => 40,
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO  => 42,
    VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO     => 43,

    VK_QUEUE_GRAPHICS_BIT               => 0x00000001,
    VK_IMAGE_ASPECT_COLOR_BIT           => 0x00000001,
    VK_FORMAT_B8G8R8A8_UNORM            => 44,
    VK_IMAGE_TYPE_2D                    => 1,
    VK_IMAGE_TILING_OPTIMAL             => 0,
    VK_IMAGE_USAGE_TRANSFER_SRC_BIT     => 0x00000001,
    VK_BUFFER_USAGE_TRANSFER_DST_BIT    => 0x00000002,
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT => 0x00000010,
    VK_SHARING_MODE_EXCLUSIVE           => 0,
    VK_IMAGE_LAYOUT_UNDEFINED           => 0,
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL => 2,
    VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL => 6,
    VK_IMAGE_VIEW_TYPE_2D               => 1,
    VK_ATTACHMENT_LOAD_OP_CLEAR         => 1,
    VK_ATTACHMENT_LOAD_OP_DONT_CARE     => 2,
    VK_ATTACHMENT_STORE_OP_STORE        => 0,
    VK_ATTACHMENT_STORE_OP_DONT_CARE    => 1,
    VK_PIPELINE_BIND_POINT_GRAPHICS     => 0,
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST => 3,
    VK_POLYGON_MODE_FILL                => 0,
    VK_CULL_MODE_NONE                   => 0,
    VK_FRONT_FACE_COUNTER_CLOCKWISE     => 1,
    VK_SAMPLE_COUNT_1_BIT               => 1,
    VK_COLOR_COMPONENT_RGBA_BITS        => 0xF,
    VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT => 0x00000002,
    VK_COMMAND_BUFFER_LEVEL_PRIMARY     => 0,
    VK_FENCE_CREATE_SIGNALED_BIT        => 0x00000001,
    VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT => 0x00000001,
    VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT => 0x00000002,
    VK_MEMORY_PROPERTY_HOST_COHERENT_BIT => 0x00000004,

    SHADERC_VERTEX_SHADER   => 0,
    SHADERC_FRAGMENT_SHADER => 1,
    SHADERC_STATUS_SUCCESS  => 0,
};

my $RtlMoveMemory_Read  = Win32::API->new('kernel32', 'RtlMoveMemory', 'PNN', 'V');
my $RtlMoveMemory_Write = Win32::API->new('kernel32', 'RtlMoveMemory', 'NPN', 'V');
my $GetModuleHandleA    = Win32::API->new('kernel32', 'GetModuleHandleA', 'P', 'N');
my $GetLastError        = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $OutputDebugStringA  = Win32::API->new('kernel32', 'OutputDebugStringA', 'P', 'V');
my $LoadLibraryA        = Win32::API->new('kernel32', 'LoadLibraryA', 'P', 'N');
my $GetProcAddress      = Win32::API->new('kernel32', 'GetProcAddress', 'NP', 'N');
my $Sleep               = Win32::API->new('kernel32', 'Sleep', 'N', 'V');

my $RegisterClassExA = Win32::API->new('user32', 'RegisterClassExA', 'P', 'I');
my $CreateWindowExA  = Win32::API->new('user32', 'CreateWindowExA', 'NPPNNNNNNNNP', 'N');
my $DefWindowProcA   = Win32::API->new('user32', 'DefWindowProcA', 'NNNN', 'N');
my $ShowWindow       = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $UpdateWindow     = Win32::API->new('user32', 'UpdateWindow', 'N', 'I');
my $PeekMessageA     = Win32::API->new('user32', 'PeekMessageA', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageA = Win32::API->new('user32', 'DispatchMessageA', 'P', 'N');
my $IsWindow         = Win32::API->new('user32', 'IsWindow', 'N', 'I');
my $GetDC            = Win32::API->new('user32', 'GetDC', 'N', 'N');
my $ReleaseDC        = Win32::API->new('user32', 'ReleaseDC', 'NN', 'I');

my $ChoosePixelFormat = Win32::API->new('gdi32', 'ChoosePixelFormat', 'NP', 'I');
my $SetPixelFormat    = Win32::API->new('gdi32', 'SetPixelFormat', 'NIP', 'I');

my $wglCreateContext = Win32::API->new('opengl32', 'wglCreateContext', 'N', 'N');
my $wglMakeCurrent   = Win32::API->new('opengl32', 'wglMakeCurrent', 'NN', 'I');
my $wglDeleteContext = Win32::API->new('opengl32', 'wglDeleteContext', 'N', 'I');
my $wglGetProcAddress = Win32::API->new('opengl32', 'wglGetProcAddress', 'P', 'N');
my $glClearColor = Win32::API->new('opengl32', 'glClearColor', 'FFFF', 'V');
my $glClear      = Win32::API->new('opengl32', 'glClear', 'N', 'V');
my $glViewport   = Win32::API->new('opengl32', 'glViewport', 'NNNN', 'V');
my $glGetString  = Win32::API->new('opengl32', 'glGetString', 'N', 'N');
my $glFlush      = Win32::API->new('opengl32', 'glFlush', '', 'V');

my $ffi_d3d11 = FFI::Platypus->new(api => 2);
$ffi_d3d11->lib('d3d11.dll');
my $D3D11CreateDevice = $ffi_d3d11->function(
    'D3D11CreateDevice' => ['opaque', 'uint32', 'opaque', 'uint32', 'opaque', 'uint32', 'uint32', 'opaque', 'opaque', 'opaque'] => 'sint32'
);

my $ffi_dcomp = FFI::Platypus->new(api => 2);
$ffi_dcomp->lib('dcomp.dll');
my $DCompositionCreateDevice = $ffi_dcomp->function(
    'DCompositionCreateDevice' => ['opaque', 'opaque', 'opaque'] => 'sint32'
);

my $ffi_d3dc = FFI::Platypus->new(api => 2);
$ffi_d3dc->lib('d3dcompiler_47.dll');
my $D3DCompile = $ffi_d3dc->function(
    'D3DCompile' => ['opaque', 'size_t', 'string', 'opaque', 'opaque', 'string', 'string', 'uint32', 'uint32', 'opaque', 'opaque'] => 'sint32'
);

my %GL46;

my $VK_LIB = FFI::Platypus->new(api => 2);
$VK_LIB->lib('vulkan-1.dll');

sub vk_fn {
    my ($name, $args, $ret) = @_;
    return $VK_LIB->function($name => $args => $ret);
}

my $VK_CREATE_INSTANCE = vk_fn('vkCreateInstance', ['opaque', 'opaque', 'opaque'], 'sint32');
my $VK_ENUMERATE_PHYSICAL_DEVICES = vk_fn('vkEnumeratePhysicalDevices', ['opaque', 'opaque', 'opaque'], 'sint32');
my $VK_GET_PHYSICAL_DEVICE_QUEUE_FAMILY_PROPERTIES = vk_fn('vkGetPhysicalDeviceQueueFamilyProperties', ['opaque', 'opaque', 'opaque'], 'void');
my $VK_CREATE_DEVICE = vk_fn('vkCreateDevice', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_GET_DEVICE_QUEUE = vk_fn('vkGetDeviceQueue', ['opaque', 'uint32', 'uint32', 'opaque'], 'void');
my $VK_GET_PHYSICAL_DEVICE_MEMORY_PROPERTIES = vk_fn('vkGetPhysicalDeviceMemoryProperties', ['opaque', 'opaque'], 'void');
my $VK_CREATE_IMAGE = vk_fn('vkCreateImage', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_GET_IMAGE_MEMORY_REQUIREMENTS = vk_fn('vkGetImageMemoryRequirements', ['opaque', 'opaque', 'opaque'], 'void');
my $VK_ALLOCATE_MEMORY = vk_fn('vkAllocateMemory', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_BIND_IMAGE_MEMORY = vk_fn('vkBindImageMemory', ['opaque', 'opaque', 'opaque', 'sint64'], 'sint32');
my $VK_CREATE_IMAGE_VIEW = vk_fn('vkCreateImageView', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_CREATE_BUFFER = vk_fn('vkCreateBuffer', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_GET_BUFFER_MEMORY_REQUIREMENTS = vk_fn('vkGetBufferMemoryRequirements', ['opaque', 'opaque', 'opaque'], 'void');
my $VK_BIND_BUFFER_MEMORY = vk_fn('vkBindBufferMemory', ['opaque', 'opaque', 'opaque', 'sint64'], 'sint32');
my $VK_CREATE_RENDER_PASS = vk_fn('vkCreateRenderPass', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_CREATE_FRAMEBUFFER = vk_fn('vkCreateFramebuffer', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_CREATE_SHADER_MODULE = vk_fn('vkCreateShaderModule', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_DESTROY_SHADER_MODULE = vk_fn('vkDestroyShaderModule', ['opaque', 'opaque', 'opaque'], 'void');
my $VK_CREATE_PIPELINE_LAYOUT = vk_fn('vkCreatePipelineLayout', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_CREATE_GRAPHICS_PIPELINES = vk_fn('vkCreateGraphicsPipelines', ['opaque', 'opaque', 'uint32', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_CREATE_COMMAND_POOL = vk_fn('vkCreateCommandPool', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_ALLOCATE_COMMAND_BUFFERS = vk_fn('vkAllocateCommandBuffers', ['opaque', 'opaque', 'opaque'], 'sint32');
my $VK_CREATE_FENCE = vk_fn('vkCreateFence', ['opaque', 'opaque', 'opaque', 'opaque'], 'sint32');
my $VK_WAIT_FOR_FENCES = vk_fn('vkWaitForFences', ['opaque', 'uint32', 'opaque', 'uint32', 'sint64'], 'sint32');
my $VK_RESET_FENCES = vk_fn('vkResetFences', ['opaque', 'uint32', 'opaque'], 'sint32');
my $VK_RESET_COMMAND_BUFFER = vk_fn('vkResetCommandBuffer', ['opaque', 'uint32'], 'sint32');
my $VK_BEGIN_COMMAND_BUFFER = vk_fn('vkBeginCommandBuffer', ['opaque', 'opaque'], 'sint32');
my $VK_END_COMMAND_BUFFER = vk_fn('vkEndCommandBuffer', ['opaque'], 'sint32');
my $VK_CMD_BEGIN_RENDER_PASS = vk_fn('vkCmdBeginRenderPass', ['opaque', 'opaque', 'uint32'], 'void');
my $VK_CMD_END_RENDER_PASS = vk_fn('vkCmdEndRenderPass', ['opaque'], 'void');
my $VK_CMD_BIND_PIPELINE = vk_fn('vkCmdBindPipeline', ['opaque', 'uint32', 'opaque'], 'void');
my $VK_CMD_DRAW = vk_fn('vkCmdDraw', ['opaque', 'uint32', 'uint32', 'uint32', 'uint32'], 'void');
my $VK_CMD_COPY_IMAGE_TO_BUFFER = vk_fn('vkCmdCopyImageToBuffer', ['opaque', 'opaque', 'uint32', 'opaque', 'uint32', 'opaque'], 'void');
my $VK_QUEUE_SUBMIT = vk_fn('vkQueueSubmit', ['opaque', 'uint32', 'opaque', 'opaque'], 'sint32');
my $VK_MAP_MEMORY = vk_fn('vkMapMemory', ['opaque', 'opaque', 'sint64', 'sint64', 'uint32', 'opaque'], 'sint32');
my $VK_UNMAP_MEMORY = vk_fn('vkUnmapMemory', ['opaque', 'opaque'], 'void');
my $VK_DEVICE_WAIT_IDLE = vk_fn('vkDeviceWaitIdle', ['opaque'], 'sint32');

my $hwnd = 0;
my $device = 0;
my $ctx = 0;
my $dcomp_device = 0;
my $dcomp_target = 0;
my $root_visual = 0;
my $gl_pf_set = 0;

sub log_msg {
    my ($msg) = @_;
    my $text = "[PerlDComp] $msg";
    print "$text\n";
    $OutputDebugStringA->Call($text . "\0");
}

sub write_mem {
    my ($dest, $data) = @_;
    my $src = scalar_to_pointer($data);
    memcpy($dest, $src, length($data));
}

sub read_mem {
    my ($addr, $size) = @_;
    return buffer_to_scalar($addr, $size);
}

sub alloc_zero {
    my ($size) = @_;
    my $ptr = malloc($size);
    die "malloc failed" unless $ptr;
    write_mem($ptr, "\0" x $size);
    return $ptr;
}

sub alloc_cstr {
    my ($text) = @_;
    my $buf = $text . "\0";
    my $ptr = malloc(length($buf));
    die "malloc failed" unless $ptr;
    write_mem($ptr, $buf);
    return $ptr;
}

sub read_u32 { unpack('L', read_mem($_[0] + $_[1], 4)); }
sub read_i32 { unpack('l', read_mem($_[0] + $_[1], 4)); }
sub read_u64 { unpack('Q', read_mem($_[0] + $_[1], 8)); }
sub write_u32 { write_mem($_[0] + $_[1], pack('L', $_[2])); }
sub write_i32 { write_mem($_[0] + $_[1], pack('l', $_[2])); }
sub write_u64 { write_mem($_[0] + $_[1], pack('Q', $_[2])); }
sub write_f32 { write_mem($_[0] + $_[1], pack('f', $_[2])); }

sub read_cstr {
    my ($addr, $max_len) = @_;
    $max_len ||= 4096;
    my $buf = read_mem($addr, $max_len);
    $buf =~ s/\0.*//s;
    return $buf;
}

sub guid_from_string {
    my ($text) = @_;
    $text =~ s/-//g;
    my @bytes = map { hex($_) } ($text =~ /../g);
    my @le = (
        $bytes[3], $bytes[2], $bytes[1], $bytes[0],
        $bytes[5], $bytes[4],
        $bytes[7], $bytes[6],
        @bytes[8 .. 15]
    );
    my $ptr = alloc_zero(16);
    write_mem($ptr, pack('C*', @le));
    return $ptr;
}

sub com_call {
    my ($obj, $index, $ret_type, $arg_types, @args) = @_;
    return 0 unless $obj;
    my $vtbl = read_u64($obj, 0);
    my $fn_ptr = read_u64($vtbl, $index * 8);
    my $fn = $ffi->function($fn_ptr => $arg_types => $ret_type);
    return $fn->call(@args);
}

sub com_release {
    my ($obj) = @_;
    return unless $obj;
    com_call($obj, 2, 'uint32', ['opaque'], $obj);
}

sub blob_ptr {
    my ($blob) = @_;
    return com_call($blob, 3, 'opaque', ['opaque'], $blob);
}

sub blob_size {
    my ($blob) = @_;
    return com_call($blob, 4, 'size_t', ['opaque'], $blob);
}

sub gl_proc {
    my ($name, $ret, $args) = @_;
    my $addr = $wglGetProcAddress->Call($name . "\0");
    die "wglGetProcAddress failed: $name" unless $addr;
    return $ffi->function($addr => $args => $ret);
}

sub init_gl46 {
    return if %GL46;
    $GL46{wglCreateContextAttribsARB} = gl_proc('wglCreateContextAttribsARB', 'opaque', ['opaque', 'opaque', 'opaque']);
    $GL46{glCreateShader} = gl_proc('glCreateShader', 'uint32', ['uint32']);
    $GL46{glShaderSource} = gl_proc('glShaderSource', 'void', ['uint32', 'sint32', 'opaque', 'opaque']);
    $GL46{glCompileShader} = gl_proc('glCompileShader', 'void', ['uint32']);
    $GL46{glGetShaderiv} = gl_proc('glGetShaderiv', 'void', ['uint32', 'uint32', 'opaque']);
    $GL46{glGetShaderInfoLog} = gl_proc('glGetShaderInfoLog', 'void', ['uint32', 'sint32', 'opaque', 'opaque']);
    $GL46{glCreateProgram} = gl_proc('glCreateProgram', 'uint32', []);
    $GL46{glAttachShader} = gl_proc('glAttachShader', 'void', ['uint32', 'uint32']);
    $GL46{glLinkProgram} = gl_proc('glLinkProgram', 'void', ['uint32']);
    $GL46{glGetProgramiv} = gl_proc('glGetProgramiv', 'void', ['uint32', 'uint32', 'opaque']);
    $GL46{glGetProgramInfoLog} = gl_proc('glGetProgramInfoLog', 'void', ['uint32', 'sint32', 'opaque', 'opaque']);
    $GL46{glUseProgram} = gl_proc('glUseProgram', 'void', ['uint32']);
    $GL46{glGenVertexArrays} = gl_proc('glGenVertexArrays', 'void', ['sint32', 'opaque']);
    $GL46{glBindVertexArray} = gl_proc('glBindVertexArray', 'void', ['uint32']);
    $GL46{glGenBuffers} = gl_proc('glGenBuffers', 'void', ['sint32', 'opaque']);
    $GL46{glBindBuffer} = gl_proc('glBindBuffer', 'void', ['uint32', 'uint32']);
    $GL46{glBufferData} = gl_proc('glBufferData', 'void', ['uint32', 'size_t', 'opaque', 'uint32']);
    $GL46{glVertexAttribPointer} = gl_proc('glVertexAttribPointer', 'void', ['uint32', 'sint32', 'uint32', 'uint8', 'sint32', 'opaque']);
    $GL46{glEnableVertexAttribArray} = gl_proc('glEnableVertexAttribArray', 'void', ['uint32']);
    $GL46{glDrawArrays} = gl_proc('glDrawArrays', 'void', ['uint32', 'sint32', 'sint32']);
}

sub gl46_call {
    my ($name, @args) = @_;
    return $GL46{$name}->call(@args);
}

sub compile_gl_shader {
    my ($type, $source) = @_;
    my $shader = gl46_call('glCreateShader', $type);
    my $src_ptr = alloc_cstr($source);
    my $src_ptrs = alloc_zero(8);
    write_u64($src_ptrs, 0, $src_ptr);
    my $src_len = alloc_zero(4);
    write_i32($src_len, 0, length($source));
    gl46_call('glShaderSource', $shader, 1, $src_ptrs, $src_len);
    gl46_call('glCompileShader', $shader);

    my $status = alloc_zero(4);
    gl46_call('glGetShaderiv', $shader, GL_COMPILE_STATUS, $status);
    if (read_i32($status, 0) != 1) {
        my $len = alloc_zero(4);
        gl46_call('glGetShaderiv', $shader, GL_INFO_LOG_LENGTH, $len);
        my $log_len = read_i32($len, 0);
        if ($log_len > 1) {
            my $buf = alloc_zero($log_len);
            my $out_len = alloc_zero(4);
            gl46_call('glGetShaderInfoLog', $shader, $log_len, $out_len, $buf);
            die 'OpenGL shader compile failed: ' . read_cstr($buf, $log_len);
        }
        die 'OpenGL shader compile failed';
    }
    return $shader;
}

sub link_gl_program {
    my ($vs, $fs) = @_;
    my $prog = gl46_call('glCreateProgram');
    gl46_call('glAttachShader', $prog, $vs);
    gl46_call('glAttachShader', $prog, $fs);
    gl46_call('glLinkProgram', $prog);

    my $status = alloc_zero(4);
    gl46_call('glGetProgramiv', $prog, GL_LINK_STATUS, $status);
    if (read_i32($status, 0) != 1) {
        my $len = alloc_zero(4);
        gl46_call('glGetProgramiv', $prog, GL_INFO_LOG_LENGTH, $len);
        my $log_len = read_i32($len, 0);
        if ($log_len > 1) {
            my $buf = alloc_zero($log_len);
            my $out_len = alloc_zero(4);
            gl46_call('glGetProgramInfoLog', $prog, $log_len, $out_len, $buf);
            die 'OpenGL program link failed: ' . read_cstr($buf, $log_len);
        }
        die 'OpenGL program link failed';
    }
    return $prog;
}

sub create_window {
    my $hinst = $GetModuleHandleA->Call(0);
    my $class_name = 'PerlDCompMulti';
    my $user32 = $LoadLibraryA->Call('user32.dll');
    die sprintf('LoadLibraryA(user32.dll) failed: 0x%08X', $GetLastError->Call()) unless $user32;
    my $wndproc_addr = $GetProcAddress->Call($user32, 'DefWindowProcA');
    die sprintf('GetProcAddress(DefWindowProcA) failed: 0x%08X', $GetLastError->Call()) unless $wndproc_addr;

    my $class_name_ptr = alloc_cstr($class_name);
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80,
        CS_OWNDC,
        $wndproc_addr,
        0,
        0,
        $hinst,
        0,
        0,
        0,
        0,
        $class_name_ptr,
        0,
    );

    my $atom = $RegisterClassExA->Call($wndclass);
    die sprintf('RegisterClassExA failed: 0x%08X', $GetLastError->Call()) unless $atom;
    log_msg("RegisterClassExA atom=$atom");

    $hwnd = $CreateWindowExA->Call(
        0,
        $class_name,
        'OpenGL + D3D11 + Vulkan (DirectComposition / Perl)',
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        $WINDOW_W,
        $WINDOW_H,
        0,
        0,
        $hinst,
        0,
    );
    die sprintf('CreateWindowExA failed: 0x%08X', $GetLastError->Call()) unless $hwnd;

    $ShowWindow->Call($hwnd, SW_SHOW);
    $UpdateWindow->Call($hwnd);
    log_msg(sprintf('CreateWindowExA hwnd=0x%X', $hwnd));
}

sub create_d3d11_device {
    my $feature_levels = alloc_zero(4);
    write_u32($feature_levels, 0, D3D_FEATURE_LEVEL_11_0);
    my $p_device = alloc_zero(8);
    my $p_ctx = alloc_zero(8);

    my $hr = $D3D11CreateDevice->call(
        0,
        D3D_DRIVER_TYPE_HARDWARE,
        0,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        $feature_levels,
        1,
        D3D11_SDK_VERSION,
        $p_device,
        0,
        $p_ctx,
    );
    die sprintf('D3D11CreateDevice failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;

    $device = read_u64($p_device, 0);
    $ctx = read_u64($p_ctx, 0);
    log_msg('D3D11 device created');
}

sub create_comp_swapchain {
    my ($width, $height) = @_;

    my $iid_dxgi_device = guid_from_string('54EC77FA-1377-44E6-8C32-88FD5F44C84C');
    my $p_dxgi_device = alloc_zero(8);
    my $hr = com_call($device, 0, 'sint32', ['opaque', 'opaque', 'opaque'], $device, $iid_dxgi_device, $p_dxgi_device);
    die sprintf('QI IDXGIDevice failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    my $dxgi_device = read_u64($p_dxgi_device, 0);

    my $p_adapter = alloc_zero(8);
    $hr = com_call($dxgi_device, 7, 'sint32', ['opaque', 'opaque'], $dxgi_device, $p_adapter);
    die sprintf('GetAdapter failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    my $adapter = read_u64($p_adapter, 0);

    my $iid_factory2 = guid_from_string('50C83A1C-E072-4C48-87B0-3630FA36A6D0');
    my $p_factory = alloc_zero(8);
    $hr = com_call($adapter, 6, 'sint32', ['opaque', 'opaque', 'opaque'], $adapter, $iid_factory2, $p_factory);
    die sprintf('GetParent(IDXGIFactory2) failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    my $factory = read_u64($p_factory, 0);

    my $created_sc = 0;
    my $last_hr = 0;
    for my $alpha_mode (DXGI_ALPHA_MODE_PREMULTIPLIED, DXGI_ALPHA_MODE_IGNORE) {
        my $scd = alloc_zero(44);
        write_u32($scd, 0,  $width);
        write_u32($scd, 4,  $height);
        write_u32($scd, 8,  DXGI_FORMAT_B8G8R8A8_UNORM);
        write_u32($scd, 12, 0);
        write_u32($scd, 16, 1);
        write_u32($scd, 20, 0);
        write_u32($scd, 24, DXGI_USAGE_RENDER_TARGET_OUTPUT);
        write_u32($scd, 28, 2);
        write_u32($scd, 32, DXGI_SCALING_STRETCH);
        write_u32($scd, 36, DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL);
        write_u32($scd, 40, $alpha_mode);

        my $p_sc = alloc_zero(8);
        $hr = com_call($factory, 24, 'sint32', ['opaque', 'opaque', 'opaque', 'opaque', 'opaque'], $factory, $device, $scd, 0, $p_sc);
        $last_hr = $hr;
        if ($hr >= 0) {
            $created_sc = read_u64($p_sc, 0);
            log_msg("CreateSwapChainForComposition succeeded (alpha=$alpha_mode)");
            last;
        }
        log_msg(sprintf('CreateSwapChainForComposition failed (alpha=%d): 0x%08X', $alpha_mode, $hr & 0xFFFFFFFF));
    }

    com_release($factory);
    com_release($adapter);
    com_release($dxgi_device);

    die sprintf('CreateSwapChainForComposition failed after retries: 0x%08X', $last_hr & 0xFFFFFFFF) unless $created_sc;
    return $created_sc;
}

sub swapchain_get_buffer {
    my ($sc) = @_;
    my $iid_tex = guid_from_string('6F15AAF2-D208-4E89-9AB4-489535D34F9C');
    my $p_tex = alloc_zero(8);
    my $hr = com_call($sc, 9, 'sint32', ['opaque', 'uint32', 'opaque', 'opaque'], $sc, 0, $iid_tex, $p_tex);
    die sprintf('SwapChain GetBuffer failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    return read_u64($p_tex, 0);
}

sub swapchain_present {
    my ($sc) = @_;
    return com_call($sc, 8, 'sint32', ['opaque', 'uint32', 'uint32'], $sc, 1, 0);
}

sub init_dcomp {
    my $iid_dxgi_device = guid_from_string('54EC77FA-1377-44E6-8C32-88FD5F44C84C');
    my $p_dxgi_device = alloc_zero(8);
    my $hr = com_call($device, 0, 'sint32', ['opaque', 'opaque', 'opaque'], $device, $iid_dxgi_device, $p_dxgi_device);
    die sprintf('QI IDXGIDevice failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    my $dxgi_device = read_u64($p_dxgi_device, 0);

    my $iid_dcomp_device = guid_from_string('C37EA93A-E7AA-450D-B16F-9746CB0407F3');
    my $p_dcomp = alloc_zero(8);
    $hr = $DCompositionCreateDevice->call($dxgi_device, $iid_dcomp_device, $p_dcomp);
    com_release($dxgi_device);
    die sprintf('DCompositionCreateDevice failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;

    $dcomp_device = read_u64($p_dcomp, 0);

    my $p_target = alloc_zero(8);
    $hr = com_call($dcomp_device, 6, 'sint32', ['opaque', 'opaque', 'sint32', 'opaque'], $dcomp_device, $hwnd, 1, $p_target);
    die 'CreateTargetForHwnd failed' if $hr < 0;
    $dcomp_target = read_u64($p_target, 0);

    my $p_root = alloc_zero(8);
    $hr = com_call($dcomp_device, 7, 'sint32', ['opaque', 'opaque'], $dcomp_device, $p_root);
    die 'CreateVisual(root) failed' if $hr < 0;
    $root_visual = read_u64($p_root, 0);

    com_call($dcomp_target, 3, 'sint32', ['opaque', 'opaque'], $dcomp_target, $root_visual);
    log_msg('DirectComposition initialized');
}

sub create_panel_visual {
    my ($sc, $offset_x) = @_;
    my $p_vis = alloc_zero(8);
    com_call($dcomp_device, 7, 'sint32', ['opaque', 'opaque'], $dcomp_device, $p_vis);
    my $vis = read_u64($p_vis, 0);
    com_call($vis, 15, 'sint32', ['opaque', 'opaque'], $vis, $sc);
    com_call($vis, 4, 'sint32', ['opaque', 'float'], $vis, $offset_x);
    com_call($vis, 6, 'sint32', ['opaque', 'float'], $vis, 0.0);
    com_call($root_visual, 16, 'sint32', ['opaque', 'opaque', 'sint32', 'opaque'], $root_visual, $vis, 1, 0);
    return $vis;
}

sub dcomp_commit {
    com_call($dcomp_device, 3, 'sint32', ['opaque'], $dcomp_device);
}

sub create_rtv {
    my ($tex) = @_;
    my $p_rtv = alloc_zero(8);
    my $hr = com_call($device, 9, 'sint32', ['opaque', 'opaque', 'opaque', 'opaque'], $device, $tex, 0, $p_rtv);
    die 'CreateRenderTargetView failed' if $hr < 0;
    return read_u64($p_rtv, 0);
}

sub d3d_create_staging_tex {
    my ($width, $height) = @_;
    my $desc = alloc_zero(44);
    write_u32($desc, 0, $width);
    write_u32($desc, 4, $height);
    write_u32($desc, 8, 1);
    write_u32($desc, 12, 1);
    write_u32($desc, 16, DXGI_FORMAT_B8G8R8A8_UNORM);
    write_u32($desc, 20, 1);
    write_u32($desc, 24, 0);
    write_u32($desc, 28, D3D11_USAGE_STAGING);
    write_u32($desc, 32, 0);
    write_u32($desc, 36, D3D11_CPU_ACCESS_WRITE);
    write_u32($desc, 40, 0);

    my $p_tex = alloc_zero(8);
    my $hr = com_call($device, 5, 'sint32', ['opaque', 'opaque', 'opaque', 'opaque'], $device, $desc, 0, $p_tex);
    die sprintf('CreateTexture2D staging failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    return read_u64($p_tex, 0);
}

sub ctx_copy_resource {
    my ($dst, $src) = @_;
    com_call($ctx, 47, 'void', ['opaque', 'opaque', 'opaque'], $ctx, $dst, $src);
}

sub ctx_map_write {
    my ($res) = @_;
    my $mapped = alloc_zero(16);
    my $hr = com_call($ctx, 14, 'sint32', ['opaque', 'opaque', 'uint32', 'uint32', 'uint32', 'opaque'], $ctx, $res, 0, D3D11_MAP_WRITE, 0, $mapped);
    die sprintf('D3D11 Map failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    return {
        p_data => read_u64($mapped, 0),
        row_pitch => read_u32($mapped, 8),
        depth_pitch => read_u32($mapped, 12),
    };
}

sub ctx_unmap {
    my ($res) = @_;
    com_call($ctx, 15, 'void', ['opaque', 'opaque', 'uint32'], $ctx, $res, 0);
}

sub compile_hlsl {
    my ($src, $entry, $target) = @_;
    my $src_ptr = alloc_cstr($src);
    my $p_code = alloc_zero(8);
    my $p_err = alloc_zero(8);
    my $hr = $D3DCompile->call($src_ptr, length($src), 'inline.hlsl', 0, 0, $entry, $target, 0, 0, $p_code, $p_err);
    if ($hr < 0) {
        my $err_blob = read_u64($p_err, 0);
        if ($err_blob) {
            my $msg = read_cstr(blob_ptr($err_blob), blob_size($err_blob));
            com_release($err_blob);
            die "D3DCompile $entry/$target failed: $msg";
        }
        die sprintf('D3DCompile %s/%s failed: 0x%08X', $entry, $target, $hr & 0xFFFFFFFF);
    }
    return read_u64($p_code, 0);
}

sub init_d3d11_triangle_pipeline {
    my ($panel) = @_;
    log_msg('Init D3D11 triangle pipeline start');

    my $hlsl = <<'HLSL';
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

    my $vs_blob = compile_hlsl($hlsl, 'VS', 'vs_4_0');
    my $ps_blob = compile_hlsl($hlsl, 'PS', 'ps_4_0');
    my $vs_ptr = blob_ptr($vs_blob);
    my $vs_size = blob_size($vs_blob);
    my $ps_ptr = blob_ptr($ps_blob);
    my $ps_size = blob_size($ps_blob);

    my $p_vs = alloc_zero(8);
    my $hr = com_call($device, 12, 'sint32', ['opaque', 'opaque', 'size_t', 'opaque', 'opaque'], $device, $vs_ptr, $vs_size, 0, $p_vs);
    die sprintf('CreateVertexShader failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    $panel->{vs} = read_u64($p_vs, 0);

    my $p_ps = alloc_zero(8);
    $hr = com_call($device, 15, 'sint32', ['opaque', 'opaque', 'size_t', 'opaque', 'opaque'], $device, $ps_ptr, $ps_size, 0, $p_ps);
    die sprintf('CreatePixelShader failed: 0x%08X', $hr & 0xFFFFFFFF) if $hr < 0;
    $panel->{ps} = read_u64($p_ps, 0);

    my $rtv_arr = alloc_zero(8);
    write_u64($rtv_arr, 0, $panel->{rtv});
    $panel->{rtv_arr} = $rtv_arr;

    my $vp = alloc_zero(24);
    write_f32($vp, 0, 0.0);
    write_f32($vp, 4, 0.0);
    write_f32($vp, 8, $PANEL_W + 0.0);
    write_f32($vp, 12, $PANEL_H + 0.0);
    write_f32($vp, 16, 0.0);
    write_f32($vp, 20, 1.0);
    $panel->{vp} = $vp;

    com_release($vs_blob);
    com_release($ps_blob);
    log_msg('Init D3D11 triangle pipeline done');
}

sub init_gl_interop_panel {
    my ($panel) = @_;
    log_msg('Init OpenGL interop panel start');

    my $hdc = $GetDC->Call($hwnd);
    die 'GetDC failed for OpenGL panel' unless $hdc;

    unless ($gl_pf_set) {
        my $pfd = pack('S S L C C C C C C C C C C C C C C C C C C L L L',
            40,
            1,
            PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
            PFD_TYPE_RGBA,
            32,
            0, 0, 0, 0, 0, 0,
            0, 0,
            0, 0, 0, 0, 0,
            24,
            0,
            0,
            PFD_MAIN_PLANE,
            0,
            0, 0, 0,
        );
        my $pf = $ChoosePixelFormat->Call($hdc, $pfd);
        die 'ChoosePixelFormat failed' unless $pf;
        die 'SetPixelFormat failed' unless $SetPixelFormat->Call($hdc, $pf, $pfd);
        $gl_pf_set = 1;
    }

    my $hrc_old = $wglCreateContext->Call($hdc);
    die 'wglCreateContext failed' unless $hrc_old;
    die 'wglMakeCurrent failed' unless $wglMakeCurrent->Call($hdc, $hrc_old);

    init_gl46();

    my $attribs = alloc_zero(20);
    write_i32($attribs, 0, WGL_CONTEXT_MAJOR_VERSION_ARB);
    write_i32($attribs, 4, 4);
    write_i32($attribs, 8, WGL_CONTEXT_MINOR_VERSION_ARB);
    write_i32($attribs, 12, 6);
    write_i32($attribs, 16, WGL_CONTEXT_PROFILE_MASK_ARB);
    my $attribs2 = alloc_zero(8);
    write_i32($attribs2, 0, WGL_CONTEXT_CORE_PROFILE_BIT_ARB);
    write_i32($attribs2, 4, 0);
    my $packed = pack('l*',
        WGL_CONTEXT_MAJOR_VERSION_ARB, 4,
        WGL_CONTEXT_MINOR_VERSION_ARB, 6,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    );
    my $attr_ptr = alloc_zero(length($packed));
    write_mem($attr_ptr, $packed);

    my $hrc = gl46_call('wglCreateContextAttribsARB', $hdc, 0, $attr_ptr);
    die 'wglCreateContextAttribsARB failed' unless $hrc;
    die 'wglMakeCurrent(GL4.6) failed' unless $wglMakeCurrent->Call($hdc, $hrc);
    $wglDeleteContext->Call($hrc_old);

    my $gl_ver_ptr = $glGetString->Call(GL_VERSION);
    my $sl_ver_ptr = $glGetString->Call(GL_SHADING_LANGUAGE_VERSION);
    log_msg('OpenGL VERSION=' . read_cstr($gl_ver_ptr, 128)) if $gl_ver_ptr;
    log_msg('GLSL VERSION=' . read_cstr($sl_ver_ptr, 128)) if $sl_ver_ptr;

    my $wgl_dx_open = gl_proc('wglDXOpenDeviceNV', 'opaque', ['opaque']);
    my $wgl_dx_close = gl_proc('wglDXCloseDeviceNV', 'sint32', ['opaque']);
    my $wgl_dx_register = gl_proc('wglDXRegisterObjectNV', 'opaque', ['opaque', 'opaque', 'uint32', 'uint32', 'uint32']);
    my $wgl_dx_unregister = gl_proc('wglDXUnregisterObjectNV', 'sint32', ['opaque', 'opaque']);
    my $wgl_dx_lock = gl_proc('wglDXLockObjectsNV', 'sint32', ['opaque', 'sint32', 'opaque']);
    my $wgl_dx_unlock = gl_proc('wglDXUnlockObjectsNV', 'sint32', ['opaque', 'sint32', 'opaque']);

    my $gl_gen_rbo = gl_proc('glGenRenderbuffers', 'void', ['sint32', 'opaque']);
    my $gl_bind_rbo = gl_proc('glBindRenderbuffer', 'void', ['uint32', 'uint32']);
    my $gl_gen_fbo = gl_proc('glGenFramebuffers', 'void', ['sint32', 'opaque']);
    my $gl_bind_fbo = gl_proc('glBindFramebuffer', 'void', ['uint32', 'uint32']);
    my $gl_fb_rbo = gl_proc('glFramebufferRenderbuffer', 'void', ['uint32', 'uint32', 'uint32', 'uint32']);

    my $interop_dev = $wgl_dx_open->call($device);
    die 'wglDXOpenDeviceNV failed' unless $interop_dev;

    my $p_rbo = alloc_zero(4);
    $gl_gen_rbo->call(1, $p_rbo);
    my $rbo = read_u32($p_rbo, 0);
    die 'glGenRenderbuffers failed' unless $rbo;
    $gl_bind_rbo->call(GL_RENDERBUFFER, $rbo);

    my $interop_obj = $wgl_dx_register->call($interop_dev, $panel->{bb}, $rbo, GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
    die 'wglDXRegisterObjectNV failed' unless $interop_obj;

    my $p_fbo = alloc_zero(4);
    $gl_gen_fbo->call(1, $p_fbo);
    my $fbo = read_u32($p_fbo, 0);
    die 'glGenFramebuffers failed' unless $fbo;
    $gl_bind_fbo->call(GL_FRAMEBUFFER, $fbo);
    $gl_fb_rbo->call(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, $rbo);
    $gl_bind_fbo->call(GL_FRAMEBUFFER, 0);

    my $vs_src = "#version 460 core\nlayout(location=0) in vec3 pos;\nlayout(location=1) in vec3 col;\nout vec3 vCol;\nvoid main(){ vCol = col; gl_Position = vec4(pos.x, -pos.y, pos.z, 1.0); }\n";
    my $fs_src = "#version 460 core\nin vec3 vCol;\nout vec4 outColor;\nvoid main(){ outColor = vec4(vCol, 1.0); }\n";
    my $vs = compile_gl_shader(GL_VERTEX_SHADER, $vs_src);
    my $fs = compile_gl_shader(GL_FRAGMENT_SHADER, $fs_src);
    my $prog = link_gl_program($vs, $fs);

    my $vao_buf = alloc_zero(4);
    gl46_call('glGenVertexArrays', 1, $vao_buf);
    my $vao = read_u32($vao_buf, 0);
    gl46_call('glBindVertexArray', $vao);

    my $vbos = alloc_zero(8);
    gl46_call('glGenBuffers', 2, $vbos);
    my $vbo_pos = read_u32($vbos, 0);
    my $vbo_col = read_u32($vbos, 4);

    my $pos = alloc_zero(36);
    write_mem($pos, pack('f*', 0.0, 0.5, 0.0, 0.5, -0.5, 0.0, -0.5, -0.5, 0.0));
    my $col = alloc_zero(36);
    write_mem($col, pack('f*', 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0));

    gl46_call('glBindBuffer', GL_ARRAY_BUFFER, $vbo_pos);
    gl46_call('glBufferData', GL_ARRAY_BUFFER, 36, $pos, GL_STATIC_DRAW);
    gl46_call('glVertexAttribPointer', 0, 3, GL_FLOAT, GL_FALSE, 0, 0);
    gl46_call('glEnableVertexAttribArray', 0);

    gl46_call('glBindBuffer', GL_ARRAY_BUFFER, $vbo_col);
    gl46_call('glBufferData', GL_ARRAY_BUFFER, 36, $col, GL_STATIC_DRAW);
    gl46_call('glVertexAttribPointer', 1, 3, GL_FLOAT, GL_FALSE, 0, 0);
    gl46_call('glEnableVertexAttribArray', 1);

    gl46_call('glBindVertexArray', 0);

    $panel->{gl_hdc} = $hdc;
    $panel->{gl_hrc} = $hrc;
    $panel->{gl_interop_dev} = $interop_dev;
    $panel->{gl_interop_obj} = $interop_obj;
    $panel->{gl_rbo} = $rbo;
    $panel->{gl_fbo} = $fbo;
    $panel->{wgl_dx_close} = $wgl_dx_close;
    $panel->{wgl_dx_unregister} = $wgl_dx_unregister;
    $panel->{wgl_dx_lock} = $wgl_dx_lock;
    $panel->{wgl_dx_unlock} = $wgl_dx_unlock;
    $panel->{gl_bind_fbo} = $gl_bind_fbo;
    $panel->{gl_program} = $prog;
    $panel->{gl_vao} = $vao;
    $panel->{gl_vbo_pos} = $vbo_pos;
    $panel->{gl_vbo_col} = $vbo_col;

    log_msg('Init OpenGL interop panel done');
}

sub render_gl_interop_panel {
    my ($panel, $bg) = @_;
    return 0 unless $panel->{gl_hrc};

    $wglMakeCurrent->Call($panel->{gl_hdc}, $panel->{gl_hrc});

    my $obj_arr = alloc_zero(8);
    write_u64($obj_arr, 0, $panel->{gl_interop_obj});
    my $lock_ok = $panel->{wgl_dx_lock}->call($panel->{gl_interop_dev}, 1, $obj_arr);
    unless ($lock_ok) {
        log_msg('wglDXLockObjectsNV failed; using fallback renderer for this frame');
        return 0;
    }

    $panel->{gl_bind_fbo}->call(GL_FRAMEBUFFER, $panel->{gl_fbo});
    $glViewport->Call(0, 0, $PANEL_W, $PANEL_H);
    $glClearColor->Call($bg->[0], $bg->[1], $bg->[2], 1.0);
    $glClear->Call(GL_COLOR_BUFFER_BIT);
    gl46_call('glUseProgram', $panel->{gl_program});
    gl46_call('glBindVertexArray', $panel->{gl_vao});
    gl46_call('glDrawArrays', GL_TRIANGLES, 0, 3);
    gl46_call('glBindVertexArray', 0);
    $glFlush->Call();
    $panel->{gl_bind_fbo}->call(GL_FRAMEBUFFER, 0);
    $panel->{wgl_dx_unlock}->call($panel->{gl_interop_dev}, 1, $obj_arr);

    my $hr = swapchain_present($panel->{sc});
    if ($hr < 0) {
        log_msg(sprintf('OpenGL panel Present failed: 0x%08X', $hr & 0xFFFFFFFF));
        return 0;
    }
    unless ($panel->{first_present_logged}) {
        log_msg($panel->{name} . ' first present succeeded');
        $panel->{first_present_logged} = 1;
    }
    return 1;
}

sub cleanup_gl_interop_panel {
    my ($panel) = @_;
    return unless $panel->{gl_hrc};
    if ($panel->{wgl_dx_unregister} && $panel->{gl_interop_dev} && $panel->{gl_interop_obj}) {
        $panel->{wgl_dx_unregister}->call($panel->{gl_interop_dev}, $panel->{gl_interop_obj});
    }
    if ($panel->{wgl_dx_close} && $panel->{gl_interop_dev}) {
        $panel->{wgl_dx_close}->call($panel->{gl_interop_dev});
    }
    $wglMakeCurrent->Call(0, 0);
    $wglDeleteContext->Call($panel->{gl_hrc}) if $panel->{gl_hrc};
    $ReleaseDC->Call($hwnd, $panel->{gl_hdc}) if $panel->{gl_hdc};
}

sub clear_rtv {
    my ($rtv, $r, $g, $b, $a) = @_;
    my $color = alloc_zero(16);
    write_mem($color, pack('f4', $r, $g, $b, $a));
    com_call($ctx, 50, 'void', ['opaque', 'opaque', 'opaque'], $ctx, $rtv, $color);
}

sub render_triangle_panel {
    my ($panel, $bg) = @_;
    clear_rtv($panel->{rtv}, $bg->[0], $bg->[1], $bg->[2], 1.0);
    com_call($ctx, 33, 'void', ['opaque', 'uint32', 'opaque', 'opaque'], $ctx, 1, $panel->{rtv_arr}, 0);
    com_call($ctx, 44, 'void', ['opaque', 'uint32', 'opaque'], $ctx, 1, $panel->{vp});
    com_call($ctx, 17, 'void', ['opaque', 'opaque'], $ctx, 0);
    com_call($ctx, 24, 'void', ['opaque', 'uint32'], $ctx, 4);
    com_call($ctx, 11, 'void', ['opaque', 'opaque', 'opaque', 'uint32'], $ctx, $panel->{vs}, 0, 0);
    com_call($ctx, 9, 'void', ['opaque', 'opaque', 'opaque', 'uint32'], $ctx, $panel->{ps}, 0, 0);
    com_call($ctx, 13, 'void', ['opaque', 'uint32', 'uint32'], $ctx, 3, 0);

    my $hr = swapchain_present($panel->{sc});
    if ($hr < 0) {
        log_msg(sprintf('Triangle panel Present failed: 0x%08X', $hr & 0xFFFFFFFF));
        return 0;
    }
    unless ($panel->{first_present_logged}) {
        log_msg($panel->{name} . ' first present succeeded');
        $panel->{first_present_logged} = 1;
    }
    return 1;
}

sub create_panel {
    my ($offset_x) = @_;
    my $sc = create_comp_swapchain($PANEL_W, $PANEL_H);
    my $bb = swapchain_get_buffer($sc);
    my $rtv = create_rtv($bb);
    my $vis = create_panel_visual($sc, $offset_x);
    return {
        sc => $sc,
        bb => $bb,
        rtv => $rtv,
        vis => $vis,
    };
}

package ShaderCompiler;

sub new {
    my ($class, $dll_name) = @_;
    $dll_name ||= 'shaderc_shared.dll';
    my $path = main::resolve_shaderc_path($dll_name);
    my $ffi = FFI::Platypus->new(api => 2);
    $ffi->lib($path);
    my $self = {
        ffi => $ffi,
        compiler_init => $ffi->function('shaderc_compiler_initialize' => [] => 'opaque'),
        compiler_release => $ffi->function('shaderc_compiler_release' => ['opaque'] => 'void'),
        opts_init => $ffi->function('shaderc_compile_options_initialize' => [] => 'opaque'),
        opts_release => $ffi->function('shaderc_compile_options_release' => ['opaque'] => 'void'),
        opts_set_opt => $ffi->function('shaderc_compile_options_set_optimization_level' => ['opaque', 'sint32'] => 'void'),
        compile => $ffi->function('shaderc_compile_into_spv' => ['opaque', 'opaque', 'size_t', 'sint32', 'opaque', 'opaque', 'opaque'] => 'opaque'),
        result_release => $ffi->function('shaderc_result_release' => ['opaque'] => 'void'),
        result_len => $ffi->function('shaderc_result_get_length' => ['opaque'] => 'size_t'),
        result_bytes => $ffi->function('shaderc_result_get_bytes' => ['opaque'] => 'opaque'),
        result_status => $ffi->function('shaderc_result_get_compilation_status' => ['opaque'] => 'sint32'),
        result_error => $ffi->function('shaderc_result_get_error_message' => ['opaque'] => 'opaque'),
    };
    bless $self, $class;
    return $self;
}

sub compile_glsl {
    my ($self, $source_text, $kind, $filename) = @_;
    my $compiler = $self->{compiler_init}->call();
    die 'shaderc_compiler_initialize failed' unless $compiler;
    my $options = $self->{opts_init}->call();
    die 'shaderc_compile_options_initialize failed' unless $options;
    $self->{opts_set_opt}->call($options, 2);

    my $src = main::alloc_cstr($source_text);
    my $result = $self->{compile}->call(
        $compiler,
        $src,
        length($source_text),
        $kind,
        main::alloc_cstr($filename),
        main::alloc_cstr('main'),
        $options,
    );
    die 'shaderc_compile_into_spv returned NULL' unless $result;

    if ($self->{result_status}->call($result) != main::SHADERC_STATUS_SUCCESS()) {
        my $msg_ptr = $self->{result_error}->call($result);
        my $msg = $msg_ptr ? main::read_cstr($msg_ptr, 4096) : '(no message)';
        $self->{result_release}->call($result);
        $self->{opts_release}->call($options);
        $self->{compiler_release}->call($compiler);
        die "shaderc failed: $msg";
    }

    my $len = $self->{result_len}->call($result);
    my $bytes_ptr = $self->{result_bytes}->call($result);
    my $data = main::read_mem($bytes_ptr, $len);

    $self->{result_release}->call($result);
    $self->{opts_release}->call($options);
    $self->{compiler_release}->call($compiler);
    return $data;
}

package main;

sub resolve_shaderc_path {
    my ($name) = @_;
    my $local = "$SCRIPT_DIR/$name";
    return $local if -f $local;
    if (defined $ENV{VULKAN_SDK}) {
        my $sdk = "$ENV{VULKAN_SDK}/Bin/$name";
        return $sdk if -f $sdk;
    }
    return $name;
}

sub vk_check {
    my ($res, $what) = @_;
    die "$what failed: VkResult=$res" if $res != VK_SUCCESS;
}

sub find_vk_memory_type {
    my ($mem_props, $type_bits, $required_flags) = @_;
    my $type_count = read_u32($mem_props, 0);
    for my $index (0 .. $type_count - 1) {
        my $flags = read_u32($mem_props, 4 + $index * 8);
        return $index if ($type_bits & (1 << $index)) && (($flags & $required_flags) == $required_flags);
    }
    die 'No suitable Vulkan memory type found';
}

sub init_vulkan_panel {
    my ($panel) = @_;
    log_msg('Init Vulkan panel start');

    open my $vf, '<', "$SCRIPT_DIR/hello.vert" or die "Cannot open hello.vert: $!";
    local $/;
    my $vert_src = <$vf>;
    close $vf;
    open my $ff, '<', "$SCRIPT_DIR/hello.frag" or die "Cannot open hello.frag: $!";
    my $frag_src = <$ff>;
    close $ff;

    my $compiler = ShaderCompiler->new();
    my $vert_spv = $compiler->compile_glsl($vert_src, SHADERC_VERTEX_SHADER, 'hello.vert');
    my $frag_spv = $compiler->compile_glsl($frag_src, SHADERC_FRAGMENT_SHADER, 'hello.frag');

    my $app_info = alloc_zero(48);
    write_u32($app_info, 0, VK_STRUCTURE_TYPE_APPLICATION_INFO);
    write_u64($app_info, 16, alloc_cstr('vk'));
    write_u32($app_info, 24, 1);
    write_u64($app_info, 32, alloc_cstr('none'));
    write_u32($app_info, 40, 1);
    write_u32($app_info, 44, (1 << 22));

    my $inst_ci = alloc_zero(64);
    write_u32($inst_ci, 0, VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    write_u64($inst_ci, 24, $app_info);

    my $p_inst = alloc_zero(8);
    vk_check($VK_CREATE_INSTANCE->call($inst_ci, 0, $p_inst), 'vkCreateInstance');
    $panel->{vk_instance} = read_u64($p_inst, 0);

    my $p_count = alloc_zero(4);
    vk_check($VK_ENUMERATE_PHYSICAL_DEVICES->call($panel->{vk_instance}, $p_count, 0), 'vkEnumeratePhysicalDevices(count)');
    my $dev_count = read_u32($p_count, 0);
    die 'No Vulkan physical devices found' unless $dev_count;
    my $dev_list = alloc_zero($dev_count * 8);
    vk_check($VK_ENUMERATE_PHYSICAL_DEVICES->call($panel->{vk_instance}, $p_count, $dev_list), 'vkEnumeratePhysicalDevices(list)');

    my ($pd, $qf_index) = (0, undef);
    for my $i (0 .. $dev_count - 1) {
        my $candidate = read_u64($dev_list, $i * 8);
        my $q_count_ptr = alloc_zero(4);
        $VK_GET_PHYSICAL_DEVICE_QUEUE_FAMILY_PROPERTIES->call($candidate, $q_count_ptr, 0);
        my $q_count = read_u32($q_count_ptr, 0);
        next unless $q_count;
        my $q_props = alloc_zero($q_count * 24);
        $VK_GET_PHYSICAL_DEVICE_QUEUE_FAMILY_PROPERTIES->call($candidate, $q_count_ptr, $q_props);
        for my $qi (0 .. $q_count - 1) {
            my $flags = read_u32($q_props, $qi * 24);
            if ($flags & VK_QUEUE_GRAPHICS_BIT) {
                $pd = $candidate;
                $qf_index = $qi;
                last;
            }
        }
        last if $pd;
    }
    die 'No Vulkan graphics queue family found' unless $pd;

    $panel->{vk_physical_device} = $pd;
    $panel->{vk_queue_family} = $qf_index;

    my $prio = alloc_zero(4);
    write_f32($prio, 0, 1.0);
    my $qci = alloc_zero(40);
    write_u32($qci, 0, VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
    write_u32($qci, 20, $qf_index);
    write_u32($qci, 24, 1);
    write_u64($qci, 32, $prio);

    my $dci = alloc_zero(72);
    write_u32($dci, 0, VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    write_u32($dci, 20, 1);
    write_u64($dci, 24, $qci);

    my $p_dev = alloc_zero(8);
    vk_check($VK_CREATE_DEVICE->call($pd, $dci, 0, $p_dev), 'vkCreateDevice');
    $panel->{vk_device} = read_u64($p_dev, 0);

    my $p_queue = alloc_zero(8);
    $VK_GET_DEVICE_QUEUE->call($panel->{vk_device}, $qf_index, 0, $p_queue);
    $panel->{vk_queue} = read_u64($p_queue, 0);

    my $mem_props = alloc_zero(520);
    $VK_GET_PHYSICAL_DEVICE_MEMORY_PROPERTIES->call($pd, $mem_props);

    my $img_ci = alloc_zero(88);
    write_u32($img_ci, 0, VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO);
    write_u32($img_ci, 20, VK_IMAGE_TYPE_2D);
    write_u32($img_ci, 24, VK_FORMAT_B8G8R8A8_UNORM);
    write_u32($img_ci, 28, $PANEL_W);
    write_u32($img_ci, 32, $PANEL_H);
    write_u32($img_ci, 36, 1);
    write_u32($img_ci, 40, 1);
    write_u32($img_ci, 44, 1);
    write_u32($img_ci, 48, VK_SAMPLE_COUNT_1_BIT);
    write_u32($img_ci, 52, VK_IMAGE_TILING_OPTIMAL);
    write_u32($img_ci, 56, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT);
    write_u32($img_ci, 60, VK_SHARING_MODE_EXCLUSIVE);
    write_u32($img_ci, 80, VK_IMAGE_LAYOUT_UNDEFINED);

    my $p_off_img = alloc_zero(8);
    vk_check($VK_CREATE_IMAGE->call($panel->{vk_device}, $img_ci, 0, $p_off_img), 'vkCreateImage');
    $panel->{vk_off_image} = read_u64($p_off_img, 0);

    my $mem_req = alloc_zero(24);
    $VK_GET_IMAGE_MEMORY_REQUIREMENTS->call($panel->{vk_device}, $panel->{vk_off_image}, $mem_req);
    my $img_mem_ai = alloc_zero(32);
    write_u32($img_mem_ai, 0, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO);
    write_u64($img_mem_ai, 16, read_u64($mem_req, 0));
    write_u32($img_mem_ai, 24, find_vk_memory_type($mem_props, read_u32($mem_req, 16), VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT));

    my $p_off_mem = alloc_zero(8);
    vk_check($VK_ALLOCATE_MEMORY->call($panel->{vk_device}, $img_mem_ai, 0, $p_off_mem), 'vkAllocateMemory(image)');
    $panel->{vk_off_memory} = read_u64($p_off_mem, 0);
    vk_check($VK_BIND_IMAGE_MEMORY->call($panel->{vk_device}, $panel->{vk_off_image}, $panel->{vk_off_memory}, 0), 'vkBindImageMemory');

    my $iv_ci = alloc_zero(80);
    write_u32($iv_ci, 0, VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
    write_u64($iv_ci, 24, $panel->{vk_off_image});
    write_u32($iv_ci, 32, VK_IMAGE_VIEW_TYPE_2D);
    write_u32($iv_ci, 36, VK_FORMAT_B8G8R8A8_UNORM);
    write_u32($iv_ci, 56, VK_IMAGE_ASPECT_COLOR_BIT);
    write_u32($iv_ci, 64, 1);
    write_u32($iv_ci, 72, 1);

    my $p_off_view = alloc_zero(8);
    vk_check($VK_CREATE_IMAGE_VIEW->call($panel->{vk_device}, $iv_ci, 0, $p_off_view), 'vkCreateImageView');
    $panel->{vk_off_view} = read_u64($p_off_view, 0);

    my $buf_ci = alloc_zero(56);
    write_u32($buf_ci, 0, VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO);
    write_u64($buf_ci, 24, $PANEL_W * $PANEL_H * 4);
    write_u32($buf_ci, 32, VK_BUFFER_USAGE_TRANSFER_DST_BIT);
    write_u32($buf_ci, 36, VK_SHARING_MODE_EXCLUSIVE);

    my $p_read_buf = alloc_zero(8);
    vk_check($VK_CREATE_BUFFER->call($panel->{vk_device}, $buf_ci, 0, $p_read_buf), 'vkCreateBuffer');
    $panel->{vk_readback_buffer} = read_u64($p_read_buf, 0);

    my $buf_req = alloc_zero(24);
    $VK_GET_BUFFER_MEMORY_REQUIREMENTS->call($panel->{vk_device}, $panel->{vk_readback_buffer}, $buf_req);
    my $buf_ai = alloc_zero(32);
    write_u32($buf_ai, 0, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO);
    write_u64($buf_ai, 16, read_u64($buf_req, 0));
    write_u32($buf_ai, 24, find_vk_memory_type($mem_props, read_u32($buf_req, 16), VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT));

    my $p_read_mem = alloc_zero(8);
    vk_check($VK_ALLOCATE_MEMORY->call($panel->{vk_device}, $buf_ai, 0, $p_read_mem), 'vkAllocateMemory(buffer)');
    $panel->{vk_readback_memory} = read_u64($p_read_mem, 0);
    vk_check($VK_BIND_BUFFER_MEMORY->call($panel->{vk_device}, $panel->{vk_readback_buffer}, $panel->{vk_readback_memory}, 0), 'vkBindBufferMemory');

    my $att = alloc_zero(36);
    write_u32($att, 4, VK_FORMAT_B8G8R8A8_UNORM);
    write_u32($att, 8, VK_SAMPLE_COUNT_1_BIT);
    write_u32($att, 12, VK_ATTACHMENT_LOAD_OP_CLEAR);
    write_u32($att, 16, VK_ATTACHMENT_STORE_OP_STORE);
    write_u32($att, 20, VK_ATTACHMENT_LOAD_OP_DONT_CARE);
    write_u32($att, 24, VK_ATTACHMENT_STORE_OP_DONT_CARE);
    write_u32($att, 28, VK_IMAGE_LAYOUT_UNDEFINED);
    write_u32($att, 32, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL);

    my $att_ref = alloc_zero(8);
    write_u32($att_ref, 4, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

    my $sub = alloc_zero(72);
    write_u32($sub, 4, VK_PIPELINE_BIND_POINT_GRAPHICS);
    write_u32($sub, 24, 1);
    write_u64($sub, 32, $att_ref);

    my $rp_ci = alloc_zero(64);
    write_u32($rp_ci, 0, VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    write_u32($rp_ci, 20, 1);
    write_u64($rp_ci, 24, $att);
    write_u32($rp_ci, 32, 1);
    write_u64($rp_ci, 40, $sub);

    my $p_rp = alloc_zero(8);
    vk_check($VK_CREATE_RENDER_PASS->call($panel->{vk_device}, $rp_ci, 0, $p_rp), 'vkCreateRenderPass');
    $panel->{vk_render_pass} = read_u64($p_rp, 0);

    my $fb_atts = alloc_zero(8);
    write_u64($fb_atts, 0, $panel->{vk_off_view});
    my $fb_ci = alloc_zero(64);
    write_u32($fb_ci, 0, VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO);
    write_u64($fb_ci, 24, $panel->{vk_render_pass});
    write_u32($fb_ci, 32, 1);
    write_u64($fb_ci, 40, $fb_atts);
    write_u32($fb_ci, 48, $PANEL_W);
    write_u32($fb_ci, 52, $PANEL_H);
    write_u32($fb_ci, 56, 1);

    my $p_fb = alloc_zero(8);
    vk_check($VK_CREATE_FRAMEBUFFER->call($panel->{vk_device}, $fb_ci, 0, $p_fb), 'vkCreateFramebuffer');
    $panel->{vk_framebuffer} = read_u64($p_fb, 0);

    my $vert_words = alloc_zero(length($vert_spv));
    write_mem($vert_words, $vert_spv);
    my $frag_words = alloc_zero(length($frag_spv));
    write_mem($frag_words, $frag_spv);

    my $sm_ci_vs = alloc_zero(40);
    write_u32($sm_ci_vs, 0, VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    write_u64($sm_ci_vs, 24, length($vert_spv));
    write_u64($sm_ci_vs, 32, $vert_words);
    my $p_vs_mod = alloc_zero(8);
    vk_check($VK_CREATE_SHADER_MODULE->call($panel->{vk_device}, $sm_ci_vs, 0, $p_vs_mod), 'vkCreateShaderModule(vs)');
    my $vs_mod = read_u64($p_vs_mod, 0);

    my $sm_ci_fs = alloc_zero(40);
    write_u32($sm_ci_fs, 0, VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    write_u64($sm_ci_fs, 24, length($frag_spv));
    write_u64($sm_ci_fs, 32, $frag_words);
    my $p_fs_mod = alloc_zero(8);
    vk_check($VK_CREATE_SHADER_MODULE->call($panel->{vk_device}, $sm_ci_fs, 0, $p_fs_mod), 'vkCreateShaderModule(fs)');
    my $fs_mod = read_u64($p_fs_mod, 0);

    my $stages = alloc_zero(96);
    write_u32($stages, 0, VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
    write_u32($stages, 20, 1);
    write_u64($stages, 24, $vs_mod);
    write_u64($stages, 32, alloc_cstr('main'));
    write_u32($stages, 48, VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
    write_u32($stages, 68, 0x10);
    write_u64($stages, 72, $fs_mod);
    write_u64($stages, 80, alloc_cstr('main'));

    my $vi = alloc_zero(48);
    write_u32($vi, 0, VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO);
    my $ia = alloc_zero(32);
    write_u32($ia, 0, VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO);
    write_u32($ia, 20, VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);

    my $vp = alloc_zero(24);
    write_f32($vp, 0, 0.0);
    write_f32($vp, 4, 0.0);
    write_f32($vp, 8, $PANEL_W + 0.0);
    write_f32($vp, 12, $PANEL_H + 0.0);
    write_f32($vp, 16, 0.0);
    write_f32($vp, 20, 1.0);

    my $sc = alloc_zero(16);
    write_u32($sc, 8, $PANEL_W);
    write_u32($sc, 12, $PANEL_H);

    my $vp_state = alloc_zero(48);
    write_u32($vp_state, 0, VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO);
    write_u32($vp_state, 20, 1);
    write_u64($vp_state, 24, $vp);
    write_u32($vp_state, 32, 1);
    write_u64($vp_state, 40, $sc);

    my $rs = alloc_zero(64);
    write_u32($rs, 0, VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO);
    write_u32($rs, 28, VK_POLYGON_MODE_FILL);
    write_u32($rs, 32, VK_CULL_MODE_NONE);
    write_u32($rs, 36, VK_FRONT_FACE_COUNTER_CLOCKWISE);
    write_f32($rs, 56, 1.0);

    my $ms = alloc_zero(48);
    write_u32($ms, 0, VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO);
    write_u32($ms, 20, VK_SAMPLE_COUNT_1_BIT);

    my $cb_att = alloc_zero(32);
    write_u32($cb_att, 28, VK_COLOR_COMPONENT_RGBA_BITS);
    my $cb_state = alloc_zero(56);
    write_u32($cb_state, 0, VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO);
    write_u32($cb_state, 28, 1);
    write_u64($cb_state, 32, $cb_att);

    my $pl_ci = alloc_zero(48);
    write_u32($pl_ci, 0, VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO);
    my $p_layout = alloc_zero(8);
    vk_check($VK_CREATE_PIPELINE_LAYOUT->call($panel->{vk_device}, $pl_ci, 0, $p_layout), 'vkCreatePipelineLayout');
    $panel->{vk_pipeline_layout} = read_u64($p_layout, 0);

    my $gp_ci = alloc_zero(144);
    write_u32($gp_ci, 0, VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO);
    write_u32($gp_ci, 20, 2);
    write_u64($gp_ci, 24, $stages);
    write_u64($gp_ci, 32, $vi);
    write_u64($gp_ci, 40, $ia);
    write_u64($gp_ci, 56, $vp_state);
    write_u64($gp_ci, 64, $rs);
    write_u64($gp_ci, 72, $ms);
    write_u64($gp_ci, 88, $cb_state);
    write_u64($gp_ci, 104, $panel->{vk_pipeline_layout});
    write_u64($gp_ci, 112, $panel->{vk_render_pass});

    my $p_pipeline = alloc_zero(8);
    vk_check($VK_CREATE_GRAPHICS_PIPELINES->call($panel->{vk_device}, 0, 1, $gp_ci, 0, $p_pipeline), 'vkCreateGraphicsPipelines');
    $panel->{vk_pipeline} = read_u64($p_pipeline, 0);
    $VK_DESTROY_SHADER_MODULE->call($panel->{vk_device}, $vs_mod, 0);
    $VK_DESTROY_SHADER_MODULE->call($panel->{vk_device}, $fs_mod, 0);

    my $cp_ci = alloc_zero(24);
    write_u32($cp_ci, 0, VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO);
    write_u32($cp_ci, 16, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
    write_u32($cp_ci, 20, $qf_index);
    my $p_cmd_pool = alloc_zero(8);
    vk_check($VK_CREATE_COMMAND_POOL->call($panel->{vk_device}, $cp_ci, 0, $p_cmd_pool), 'vkCreateCommandPool');
    $panel->{vk_cmd_pool} = read_u64($p_cmd_pool, 0);

    my $cb_ai = alloc_zero(32);
    write_u32($cb_ai, 0, VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO);
    write_u64($cb_ai, 16, $panel->{vk_cmd_pool});
    write_u32($cb_ai, 24, VK_COMMAND_BUFFER_LEVEL_PRIMARY);
    write_u32($cb_ai, 28, 1);
    my $p_cmd_buf = alloc_zero(8);
    vk_check($VK_ALLOCATE_COMMAND_BUFFERS->call($panel->{vk_device}, $cb_ai, $p_cmd_buf), 'vkAllocateCommandBuffers');
    $panel->{vk_cmd_buf} = read_u64($p_cmd_buf, 0);

    my $fence_ci = alloc_zero(24);
    write_u32($fence_ci, 0, VK_STRUCTURE_TYPE_FENCE_CREATE_INFO);
    write_u32($fence_ci, 16, VK_FENCE_CREATE_SIGNALED_BIT);
    my $p_fence = alloc_zero(8);
    vk_check($VK_CREATE_FENCE->call($panel->{vk_device}, $fence_ci, 0, $p_fence), 'vkCreateFence');
    $panel->{vk_fence} = read_u64($p_fence, 0);

    $panel->{vk_staging_tex} = d3d_create_staging_tex($PANEL_W, $PANEL_H);
    $panel->{vk_buffer_size} = $PANEL_W * $PANEL_H * 4;
    log_msg('Init Vulkan panel done');
}

sub render_vulkan_panel {
    my ($panel) = @_;
    my $fences = alloc_zero(8);
    write_u64($fences, 0, $panel->{vk_fence});
    vk_check($VK_WAIT_FOR_FENCES->call($panel->{vk_device}, 1, $fences, 1, -1), 'vkWaitForFences');
    vk_check($VK_RESET_FENCES->call($panel->{vk_device}, 1, $fences), 'vkResetFences');
    vk_check($VK_RESET_COMMAND_BUFFER->call($panel->{vk_cmd_buf}, 0), 'vkResetCommandBuffer');

    my $cb_bi = alloc_zero(32);
    write_u32($cb_bi, 0, VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO);
    vk_check($VK_BEGIN_COMMAND_BUFFER->call($panel->{vk_cmd_buf}, $cb_bi), 'vkBeginCommandBuffer');

    my $clear = alloc_zero(16);
    write_mem($clear, pack('f4', 0.15, 0.05, 0.05, 1.0));
    my $rp_bi = alloc_zero(64);
    write_u32($rp_bi, 0, VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
    write_u64($rp_bi, 16, $panel->{vk_render_pass});
    write_u64($rp_bi, 24, $panel->{vk_framebuffer});
    write_u32($rp_bi, 40, $PANEL_W);
    write_u32($rp_bi, 44, $PANEL_H);
    write_u32($rp_bi, 48, 1);
    write_u64($rp_bi, 56, $clear);

    $VK_CMD_BEGIN_RENDER_PASS->call($panel->{vk_cmd_buf}, $rp_bi, 0);
    $VK_CMD_BIND_PIPELINE->call($panel->{vk_cmd_buf}, VK_PIPELINE_BIND_POINT_GRAPHICS, $panel->{vk_pipeline});
    $VK_CMD_DRAW->call($panel->{vk_cmd_buf}, 3, 1, 0, 0);
    $VK_CMD_END_RENDER_PASS->call($panel->{vk_cmd_buf});

    my $region = alloc_zero(56);
    write_u32($region, 8, $PANEL_W);
    write_u32($region, 12, $PANEL_H);
    write_u32($region, 16, VK_IMAGE_ASPECT_COLOR_BIT);
    write_u32($region, 28, 1);
    write_u32($region, 44, $PANEL_W);
    write_u32($region, 48, $PANEL_H);
    write_u32($region, 52, 1);
    $VK_CMD_COPY_IMAGE_TO_BUFFER->call($panel->{vk_cmd_buf}, $panel->{vk_off_image}, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, $panel->{vk_readback_buffer}, 1, $region);
    vk_check($VK_END_COMMAND_BUFFER->call($panel->{vk_cmd_buf}), 'vkEndCommandBuffer');

    my $cmd_arr = alloc_zero(8);
    write_u64($cmd_arr, 0, $panel->{vk_cmd_buf});
    my $submit = alloc_zero(72);
    write_u32($submit, 0, VK_STRUCTURE_TYPE_SUBMIT_INFO);
    write_u32($submit, 40, 1);
    write_u64($submit, 48, $cmd_arr);
    vk_check($VK_QUEUE_SUBMIT->call($panel->{vk_queue}, 1, $submit, $panel->{vk_fence}), 'vkQueueSubmit');
    vk_check($VK_WAIT_FOR_FENCES->call($panel->{vk_device}, 1, $fences, 1, -1), 'vkWaitForFences(post-submit)');

    my $p_vk_data = alloc_zero(8);
    vk_check($VK_MAP_MEMORY->call($panel->{vk_device}, $panel->{vk_readback_memory}, 0, $panel->{vk_buffer_size}, 0, $p_vk_data), 'vkMapMemory');
    my $vk_data = read_u64($p_vk_data, 0);

    my $mapped = ctx_map_write($panel->{vk_staging_tex});
    my $pitch = $PANEL_W * 4;
    for my $y (0 .. $PANEL_H - 1) {
        my $row = read_mem($vk_data + $y * $pitch, $pitch);
        write_mem($mapped->{p_data} + $y * $mapped->{row_pitch}, $row);
    }
    ctx_unmap($panel->{vk_staging_tex});
    $VK_UNMAP_MEMORY->call($panel->{vk_device}, $panel->{vk_readback_memory});

    ctx_copy_resource($panel->{bb}, $panel->{vk_staging_tex});
    my $hr = swapchain_present($panel->{sc});
    if ($hr < 0) {
        log_msg(sprintf('Vulkan panel Present failed: 0x%08X', $hr & 0xFFFFFFFF));
        return 0;
    }
    unless ($panel->{first_present_logged}) {
        log_msg($panel->{name} . ' first present succeeded');
        $panel->{first_present_logged} = 1;
    }
    return 1;
}

sub cleanup_vulkan_panel {
    my ($panel) = @_;
    return unless $panel->{vk_device};
    $VK_DEVICE_WAIT_IDLE->call($panel->{vk_device});
    com_release($panel->{vk_staging_tex}) if $panel->{vk_staging_tex};
}

sub validate_vulkan_runtime {
    eval {
        my $ffi_vk = FFI::Platypus->new(api => 2);
        $ffi_vk->lib('vulkan-1.dll');
        my $fn = $ffi_vk->function('vkEnumerateInstanceVersion' => ['opaque'] => 'sint32');
        my $p_ver = alloc_zero(4);
        if ($fn->call($p_ver) == 0) {
            my $v = read_u32($p_ver, 0);
            my $major = ($v >> 22) & 0x3ff;
            my $minor = ($v >> 12) & 0x3ff;
            log_msg("Vulkan runtime detected: $major.$minor");
        }
    };
    if ($@) {
        log_msg('Vulkan runtime is not available. Vulkan panel stays in fallback mode.');
    }
}

sub pump_messages {
    my $msg = "\0" x 48;
    while ($PeekMessageA->Call($msg, 0, 0, 0, PM_REMOVE)) {
        my $message = unpack('L', substr($msg, 8, 4));
        return 0 if $message == WM_QUIT;
        $TranslateMessage->Call($msg);
        $DispatchMessageA->Call($msg);
    }
    return $IsWindow->Call($hwnd) ? 1 : 0;
}

sub release_panel {
    my ($panel) = @_;
    com_release($panel->{ps}) if $panel->{ps};
    com_release($panel->{vs}) if $panel->{vs};
    com_release($panel->{vis}) if $panel->{vis};
    com_release($panel->{rtv}) if $panel->{rtv};
    com_release($panel->{bb}) if $panel->{bb};
    com_release($panel->{sc}) if $panel->{sc};
}

sub main {
    log_msg('=== DirectComposition Multi Panel (Perl) ===');
    log_msg('DebugView logging is enabled');

    create_window();
    create_d3d11_device();
    init_dcomp();

    my $gl_panel = create_panel(0.0);
    my $dx_panel = create_panel($PANEL_W + 0.0);
    my $vk_panel = create_panel($PANEL_W * 2.0);
    $gl_panel->{name} = 'OpenGL panel';
    $dx_panel->{name} = 'DirectX panel';
    $vk_panel->{name} = 'Vulkan panel';

    my $gl_native = 0;
    eval {
        init_gl_interop_panel($gl_panel);
        $gl_native = 1;
    };
    if ($@) {
        chomp(my $err = $@);
        log_msg("OpenGL native path disabled: $err");
        init_d3d11_triangle_pipeline($gl_panel);
    }

    init_d3d11_triangle_pipeline($dx_panel);

    my $vk_native = 0;
    eval {
        init_vulkan_panel($vk_panel);
        $vk_native = 1;
    };
    if ($@) {
        chomp(my $err = $@);
        log_msg("Vulkan native path disabled: $err");
        init_d3d11_triangle_pipeline($vk_panel);
    }

    validate_vulkan_runtime();
    dcomp_commit();
    log_msg('Panels created. Entering render loop...');
    log_msg($gl_native ? 'Left panel: OpenGL slot (native OpenGL via WGL_NV_DX_interop)' : 'Left panel: OpenGL slot (compatibility triangle via D3D11)');
    log_msg('Center panel: DirectX slot (native D3D11 triangle)');
    log_msg($vk_native ? 'Right panel: Vulkan slot (native Vulkan offscreen + D3D11 copy)' : 'Right panel: Vulkan slot (compatibility triangle via D3D11)');

    my $frame = 0;
    while (pump_messages()) {
        if ($gl_native) {
            my $ok = render_gl_interop_panel($gl_panel, [0.06, 0.10, 0.28]);
            render_triangle_panel($gl_panel, [0.06, 0.10, 0.28]) unless $ok;
        } else {
            render_triangle_panel($gl_panel, [0.06, 0.10, 0.28]);
        }

        render_triangle_panel($dx_panel, [0.06, 0.22, 0.08]);

        if ($vk_native) {
            my $ok = render_vulkan_panel($vk_panel);
            render_triangle_panel($vk_panel, [0.24, 0.08, 0.08]) unless $ok;
        } else {
            render_triangle_panel($vk_panel, [0.24, 0.08, 0.08]);
        }

        $frame++;
        log_msg("Frame $frame") if ($frame % 120) == 0;
        $Sleep->Call(1);
    }

    log_msg("Render loop exited at frame $frame");

    cleanup_gl_interop_panel($gl_panel);
    cleanup_vulkan_panel($vk_panel);
    release_panel($gl_panel);
    release_panel($dx_panel);
    release_panel($vk_panel);
    com_release($root_visual) if $root_visual;
    com_release($dcomp_target) if $dcomp_target;
    com_release($dcomp_device) if $dcomp_device;
    com_release($ctx) if $ctx;
    com_release($device) if $device;

    log_msg('=== END ===');
}

eval { main(); 1 } or do {
    my $err = $@ || 'unknown error';
    warn "ERROR: $err\n";
    exit 1;
};
