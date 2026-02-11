#!/usr/bin/perl
# -*- coding: utf-8 -*-
# Vulkan 1.4 Raymarching (Windows, Perl, FFI::Platypus + Win32::API)
#
# - Win32 window via Win32::API
# - Vulkan via vulkan-1.dll (FFI::Platypus)
# - Runtime GLSL->SPIR-V via shaderc_shared.dll (FFI::Platypus)
# - Swapchain + renderpass + graphics pipeline
# - Fullscreen quad raymarching with push constants
#
# Requirements:
# - Strawberry Perl 5.32+ (64-bit)
# - cpan install Win32::API FFI::Platypus
# - Vulkan SDK installed (for shaderc_shared.dll)
# - vulkan-1.dll in PATH
#
# Files in same folder:
# - hello.vert
# - hello.frag

use strict;
use warnings;
use utf8;
use Win32::API;
use FFI::Platypus 2.00;
use FFI::Platypus::Memory qw(malloc free memcpy);
use FFI::Platypus::Buffer qw(buffer_to_scalar scalar_to_pointer);
use Encode qw(encode);
use File::Basename;
use Cwd 'abs_path';
use Time::HiRes qw(time);

# ============================================================
# Logging
# ============================================================
my $T0 = time();

sub log_msg {
    my ($msg) = @_;
    my $dt = time() - $T0;
    printf("[%8.3f] %s\n", $dt, $msg);
}

sub hx {
    my ($h) = @_;
    return "(null)" unless defined $h;
    return sprintf("0x%X", $h);
}

print "=== Perl Vulkan 1.4 Raymarching ===\n\n";

# ============================================================
# Script directory
# ============================================================
my $SCRIPT_DIR = dirname(abs_path($0));

# ============================================================
# 64-bit max value (avoid hex literal warning)
# ============================================================
my $UINT64_MAX = ~0;  # All bits set

# ============================================================
# Constants
# ============================================================
use constant {
    # Window styles
    CS_OWNDC            => 0x0020,
    WS_OVERLAPPEDWINDOW => 0x00CF0000,
    CW_USEDEFAULT       => 0x80000000,
    SW_SHOW             => 5,
    
    # Messages
    WM_DESTROY => 0x0002,
    WM_CLOSE   => 0x0010,
    WM_QUIT    => 0x0012,
    WM_SIZE    => 0x0005,
    PM_REMOVE  => 0x0001,
    
    # IDC/IDI
    IDI_APPLICATION => 32512,
    IDC_ARROW       => 32512,
    
    # Vulkan constants
    VK_SUCCESS                    => 0,
    VK_ERROR_OUT_OF_DATE_KHR      => -1000001004,
    VK_SUBOPTIMAL_KHR             => 1000001003,
    
    # VK_STRUCTURE_TYPE_*
    VK_STRUCTURE_TYPE_APPLICATION_INFO                      => 0,
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                  => 1,
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO              => 2,
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                    => 3,
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR         => 1000009000,
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR             => 1000001000,
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                => 15,
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO             => 16,
    VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO               => 38,
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO     => 18,
    VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO => 19,
    VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO => 20,
    VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO   => 22,
    VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO => 23,
    VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO => 24,
    VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO => 26,
    VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO    => 27,
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO           => 30,
    VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO         => 28,
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO               => 37,
    VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO              => 39,
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO          => 40,
    VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO             => 42,
    VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                => 43,
    VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                 => 9,
    VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                     => 8,
    VK_STRUCTURE_TYPE_SUBMIT_INFO                           => 4,
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                      => 1000001002,
    
    # Queue flags
    VK_QUEUE_GRAPHICS_BIT => 0x00000001,
    
    # Command pool flags
    VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT => 0x00000002,
    
    # Pipeline
    VK_PIPELINE_BIND_POINT_GRAPHICS      => 0,
    VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST  => 3,
    VK_POLYGON_MODE_FILL                 => 0,
    VK_CULL_MODE_NONE                    => 0,
    VK_FRONT_FACE_COUNTER_CLOCKWISE      => 1,
    VK_SAMPLE_COUNT_1_BIT                => 1,
    
    VK_COLOR_COMPONENT_R_BIT => 0x1,
    VK_COLOR_COMPONENT_G_BIT => 0x2,
    VK_COLOR_COMPONENT_B_BIT => 0x4,
    VK_COLOR_COMPONENT_A_BIT => 0x8,
    
    VK_DYNAMIC_STATE_VIEWPORT => 0,
    VK_DYNAMIC_STATE_SCISSOR  => 1,
    
    # Image / layout
    VK_IMAGE_ASPECT_COLOR_BIT              => 0x1,
    VK_IMAGE_VIEW_TYPE_2D                  => 1,
    VK_IMAGE_LAYOUT_UNDEFINED              => 0,
    VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL => 2,
    VK_IMAGE_LAYOUT_PRESENT_SRC_KHR        => 1000001002,
    
    # Attachment
    VK_ATTACHMENT_LOAD_OP_CLEAR   => 1,
    VK_ATTACHMENT_STORE_OP_STORE  => 0,
    VK_ATTACHMENT_LOAD_OP_DONT_CARE  => 2,
    VK_ATTACHMENT_STORE_OP_DONT_CARE => 1,
    
    # Sharing mode
    VK_SHARING_MODE_EXCLUSIVE  => 0,
    VK_SHARING_MODE_CONCURRENT => 1,
    
    # Present mode
    VK_PRESENT_MODE_FIFO_KHR => 2,
    
    # Composite alpha / transform
    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR       => 0x00000001,
    VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR   => 0x00000001,
    
    # Pipeline stage
    VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT => 0x00000400,
    
    # Fence
    VK_FENCE_CREATE_SIGNALED_BIT => 0x00000001,
    
    # Command buffer
    VK_COMMAND_BUFFER_LEVEL_PRIMARY => 0,
    
    # Shader stage
    VK_SHADER_STAGE_VERTEX_BIT   => 0x00000001,
    VK_SHADER_STAGE_FRAGMENT_BIT => 0x00000010,
    
    # Image usage
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT => 0x00000010,
    
    # Subpass contents
    VK_SUBPASS_CONTENTS_INLINE => 0,
    
    # Shaderc constants
    SHADERC_VERTEX_SHADER     => 0,
    SHADERC_FRAGMENT_SHADER   => 1,
    SHADERC_STATUS_SUCCESS    => 0,
};

# ============================================================
# Import Windows API functions
# ============================================================
log_msg("Loading Windows API...");

my $GetModuleHandleW = Win32::API->new('kernel32', 'GetModuleHandleW', 'P', 'N');
my $GetLastError = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $Sleep = Win32::API->new('kernel32', 'Sleep', 'N', 'V');
my $LoadLibraryW = Win32::API->new('kernel32', 'LoadLibraryW', 'P', 'N');
my $GetProcAddress_API = Win32::API->new('kernel32', 'GetProcAddress', 'NP', 'N');

my $RegisterClassExW = Win32::API->new('user32', 'RegisterClassExW', 'P', 'I');
my $CreateWindowExW = Win32::API->new('user32', 'CreateWindowExW', 'NPPNNNNNNNNP', 'N');
my $DefWindowProcW = Win32::API->new('user32', 'DefWindowProcW', 'NNNN', 'N');
my $LoadIconW = Win32::API->new('user32', 'LoadIconW', 'NN', 'N');
my $LoadCursorW = Win32::API->new('user32', 'LoadCursorW', 'NN', 'N');
my $ShowWindow = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $UpdateWindow = Win32::API->new('user32', 'UpdateWindow', 'N', 'I');
my $PeekMessageW = Win32::API->new('user32', 'PeekMessageW', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageW = Win32::API->new('user32', 'DispatchMessageW', 'P', 'N');
my $PostQuitMessage = Win32::API->new('user32', 'PostQuitMessage', 'N', 'V');
my $IsWindow = Win32::API->new('user32', 'IsWindow', 'N', 'I');
my $GetClientRect = Win32::API->new('user32', 'GetClientRect', 'NP', 'I');

sub encode_utf16 {
    my ($str) = @_;
    my $utf16 = encode('UTF-16LE', $str);
    $utf16 .= "\0\0";
    return $utf16;
}

# ============================================================
# FFI::Platypus setup for Vulkan
# ============================================================
log_msg("Loading vulkan-1.dll...");

my $ffi = FFI::Platypus->new(api => 2);
$ffi->lib('vulkan-1.dll');

# Load core Vulkan functions
my $vkCreateInstance = $ffi->function('vkCreateInstance' => ['opaque', 'opaque', 'opaque'] => 'sint32');
my $vkEnumeratePhysicalDevices = $ffi->function('vkEnumeratePhysicalDevices' => ['opaque', 'uint32*', 'opaque'] => 'sint32');
my $vkGetPhysicalDeviceQueueFamilyProperties = $ffi->function('vkGetPhysicalDeviceQueueFamilyProperties' => ['opaque', 'uint32*', 'opaque'] => 'void');
my $vkCreateDevice = $ffi->function('vkCreateDevice' => ['opaque', 'opaque', 'opaque', 'opaque'] => 'sint32');
my $vkGetDeviceQueue = $ffi->function('vkGetDeviceQueue' => ['opaque', 'uint32', 'uint32', 'opaque'] => 'void');
my $vkDestroyInstance = $ffi->function('vkDestroyInstance' => ['opaque', 'opaque'] => 'void');
my $vkDestroyDevice = $ffi->function('vkDestroyDevice' => ['opaque', 'opaque'] => 'void');
my $vkDeviceWaitIdle = $ffi->function('vkDeviceWaitIdle' => ['opaque'] => 'sint32');
my $vkGetInstanceProcAddr = $ffi->function('vkGetInstanceProcAddr' => ['opaque', 'string'] => 'opaque');
my $vkGetDeviceProcAddr = $ffi->function('vkGetDeviceProcAddr' => ['opaque', 'string'] => 'opaque');

# ============================================================
# Shaderc wrapper
# ============================================================
log_msg("Loading shaderc_shared.dll...");

my $shaderc_ffi = FFI::Platypus->new(api => 2);

# Try to find shaderc_shared.dll
my $shaderc_path = "shaderc_shared.dll";
if (-f "$SCRIPT_DIR/shaderc_shared.dll") {
    $shaderc_path = "$SCRIPT_DIR/shaderc_shared.dll";
} elsif (defined $ENV{VULKAN_SDK}) {
    my $sdk_path = "$ENV{VULKAN_SDK}/Bin/shaderc_shared.dll";
    if (-f $sdk_path) {
        $shaderc_path = $sdk_path;
    }
}

log_msg("Using shaderc: $shaderc_path");
$shaderc_ffi->lib($shaderc_path);

my $shaderc_compiler_initialize = $shaderc_ffi->function('shaderc_compiler_initialize' => [] => 'opaque');
my $shaderc_compiler_release = $shaderc_ffi->function('shaderc_compiler_release' => ['opaque'] => 'void');
my $shaderc_compile_options_initialize = $shaderc_ffi->function('shaderc_compile_options_initialize' => [] => 'opaque');
my $shaderc_compile_options_release = $shaderc_ffi->function('shaderc_compile_options_release' => ['opaque'] => 'void');
my $shaderc_compile_options_set_optimization_level = $shaderc_ffi->function('shaderc_compile_options_set_optimization_level' => ['opaque', 'sint32'] => 'void');
my $shaderc_compile_into_spv = $shaderc_ffi->function('shaderc_compile_into_spv' => ['opaque', 'string', 'size_t', 'sint32', 'string', 'string', 'opaque'] => 'opaque');
my $shaderc_result_release = $shaderc_ffi->function('shaderc_result_release' => ['opaque'] => 'void');
my $shaderc_result_get_length = $shaderc_ffi->function('shaderc_result_get_length' => ['opaque'] => 'size_t');
my $shaderc_result_get_bytes = $shaderc_ffi->function('shaderc_result_get_bytes' => ['opaque'] => 'opaque');
my $shaderc_result_get_compilation_status = $shaderc_ffi->function('shaderc_result_get_compilation_status' => ['opaque'] => 'sint32');
my $shaderc_result_get_error_message = $shaderc_ffi->function('shaderc_result_get_error_message' => ['opaque'] => 'string');

sub compile_shader {
    my ($source, $kind, $filename) = @_;
    
    my $compiler = $shaderc_compiler_initialize->();
    die "shaderc_compiler_initialize failed" unless $compiler;
    
    my $options = $shaderc_compile_options_initialize->();
    unless ($options) {
        $shaderc_compiler_release->($compiler);
        die "shaderc_compile_options_initialize failed";
    }
    
    # Set optimization level to 2 (performance)
    $shaderc_compile_options_set_optimization_level->($options, 2);
    
    my $result = $shaderc_compile_into_spv->(
        $compiler,
        $source,
        length($source),
        $kind,
        $filename,
        "main",
        $options
    );
    
    unless ($result) {
        $shaderc_compile_options_release->($options);
        $shaderc_compiler_release->($compiler);
        die "shaderc_compile_into_spv returned NULL";
    }
    
    my $status = $shaderc_result_get_compilation_status->($result);
    if ($status != SHADERC_STATUS_SUCCESS) {
        my $err_msg = $shaderc_result_get_error_message->($result);
        $shaderc_result_release->($result);
        $shaderc_compile_options_release->($options);
        $shaderc_compiler_release->($compiler);
        die "Shader compilation failed ($status): $err_msg";
    }
    
    my $length = $shaderc_result_get_length->($result);
    my $bytes_ptr = $shaderc_result_get_bytes->($result);
    
    # Copy SPIR-V bytes using FFI::Platypus::Buffer
    my $spv = buffer_to_scalar($bytes_ptr, $length);
    
    $shaderc_result_release->($result);
    $shaderc_compile_options_release->($options);
    $shaderc_compiler_release->($compiler);
    
    return $spv;
}

# ============================================================
# Read shader files
# ============================================================
my $vert_path = "$SCRIPT_DIR/hello.vert";
my $frag_path = "$SCRIPT_DIR/hello.frag";

die "hello.vert not found at $vert_path" unless -f $vert_path;
die "hello.frag not found at $frag_path" unless -f $frag_path;

log_msg("Reading shader: $vert_path");
open(my $vf, '<', $vert_path) or die "Cannot open $vert_path: $!";
my $vert_src = do { local $/; <$vf> };
close($vf);

log_msg("Reading shader: $frag_path");
open(my $ff, '<', $frag_path) or die "Cannot open $frag_path: $!";
my $frag_src = do { local $/; <$ff> };
close($ff);

log_msg("STEP: shaderc compile hello.vert");
my $vert_spv = compile_shader($vert_src, SHADERC_VERTEX_SHADER, "hello.vert");
log_msg("shaderc OK: hello.vert -> " . length($vert_spv) . " bytes SPIR-V");

log_msg("STEP: shaderc compile hello.frag");
my $frag_spv = compile_shader($frag_src, SHADERC_FRAGMENT_SHADER, "hello.frag");
log_msg("shaderc OK: hello.frag -> " . length($frag_spv) . " bytes SPIR-V");

# ============================================================
# Helper: Check Vulkan result
# ============================================================
sub vk_check {
    my ($res, $what) = @_;
    if ($res != VK_SUCCESS) {
        die "$what failed: VkResult=$res";
    }
}

# ============================================================
# Helper: Pack structures and get pointer
# ============================================================
sub pack_ptr {
    my ($data_ref) = @_;
    return unpack('Q', pack('P', $$data_ref));
}

sub alloc_struct {
    my ($packed) = @_;
    my $len = length($packed);
    my $ptr = malloc($len);
    die "malloc failed" unless $ptr;
    # Copy data to allocated memory using FFI memcpy
    my $src_ptr = scalar_to_pointer($packed);
    memcpy($ptr, $src_ptr, $len);
    return $ptr;
}

# ============================================================
# Create Window
# ============================================================
sub create_window {
    my ($title, $width, $height) = @_;
    
    my $hInstance = $GetModuleHandleW->Call(0);
    my $className = encode_utf16("PerlVulkanRaymarching");
    
    my $hIcon = $LoadIconW->Call(0, IDI_APPLICATION);
    my $hCursor = $LoadCursorW->Call(0, IDC_ARROW);
    
    # Get DefWindowProcW address
    my $user32_handle = $LoadLibraryW->Call(encode_utf16('user32.dll'));
    my $defproc_addr = $GetProcAddress_API->Call($user32_handle, "DefWindowProcW\0");
    
    die "Failed to get DefWindowProcW address" unless $defproc_addr;
    
    my $className_ptr = pack_ptr(\$className);
    
    # WNDCLASSEXW structure (80 bytes on 64-bit)
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80,              # cbSize
        CS_OWNDC,        # style
        $defproc_addr,   # lpfnWndProc
        0,               # cbClsExtra
        0,               # cbWndExtra
        $hInstance,      # hInstance
        $hIcon,          # hIcon
        $hCursor,        # hCursor
        0,               # hbrBackground
        0,               # lpszMenuName
        $className_ptr,  # lpszClassName
        $hIcon           # hIconSm
    );
    
    my $atom = $RegisterClassExW->Call($wndclass);
    unless ($atom) {
        my $err = $GetLastError->Call();
        die "RegisterClassExW failed: 0x" . sprintf("%08X", $err);
    }
    
    my $windowTitle = encode_utf16($title);
    
    my $hwnd = $CreateWindowExW->Call(
        0,                      # dwExStyle
        $className,             # lpClassName
        $windowTitle,           # lpWindowName
        WS_OVERLAPPEDWINDOW,    # dwStyle
        100,                    # x
        100,                    # y
        $width,                 # width
        $height,                # height
        0,                      # hwndParent
        0,                      # hMenu
        $hInstance,             # hInstance
        0                       # lpParam
    );
    
    unless ($hwnd) {
        my $err = $GetLastError->Call();
        die "CreateWindowExW failed: 0x" . sprintf("%08X", $err);
    }
    
    $ShowWindow->Call($hwnd, SW_SHOW);
    $UpdateWindow->Call($hwnd);
    
    return ($hwnd, $hInstance);
}

# ============================================================
# Get client size
# ============================================================
sub get_client_size {
    my ($hwnd) = @_;
    my $rect = pack('l4', 0, 0, 0, 0);  # RECT: left, top, right, bottom
    $GetClientRect->Call($hwnd, $rect);
    my ($left, $top, $right, $bottom) = unpack('l4', $rect);
    my $w = $right - $left;
    my $h = $bottom - $top;
    $w = 1 if $w < 1;
    $h = 1 if $h < 1;
    return ($w, $h);
}

# ============================================================
# Create Vulkan Instance
# ============================================================
sub create_vk_instance {
    # Allocate extension name strings
    my $ext1 = "VK_KHR_surface\0";
    my $ext2 = "VK_KHR_win32_surface\0";
    my $ext1_ptr = alloc_struct($ext1);
    my $ext2_ptr = alloc_struct($ext2);
    my $exts = pack('Q Q', $ext1_ptr, $ext2_ptr);
    my $exts_ptr = alloc_struct($exts);
    
    # API version 1.4
    my $api_1_4 = (1 << 22) | (4 << 12) | 0;
    
    # Allocate application name strings
    my $app_name = "PerlVulkanRaymarching\0";
    my $engine_name = "NoEngine\0";
    my $app_name_ptr = alloc_struct($app_name);
    my $engine_name_ptr = alloc_struct($engine_name);
    
    # VkApplicationInfo (48 bytes)
    # sType(4) + pad(4) + pNext(8) + pAppName(8) + appVer(4) + pad(4) + pEngName(8) + engVer(4) + apiVer(4)
    my $app_info = pack('L L Q Q L L Q L L',
        VK_STRUCTURE_TYPE_APPLICATION_INFO,  # sType
        0,                                    # padding
        0,                                    # pNext
        $app_name_ptr,                        # pApplicationName
        1,                                    # applicationVersion
        0,                                    # padding
        $engine_name_ptr,                     # pEngineName
        1,                                    # engineVersion
        $api_1_4                              # apiVersion
    );
    
    my $app_info_ptr = alloc_struct($app_info);
    
    log_msg("  VkApplicationInfo size: " . length($app_info) . " bytes");
    log_msg("  app_info_ptr: " . hx($app_info_ptr));
    log_msg("  exts_ptr: " . hx($exts_ptr));
    
    # VkInstanceCreateInfo (64 bytes)
    # sType(4) + pad(4) + pNext(8) + flags(4) + pad(4) + pAppInfo(8) + 
    # layerCount(4) + pad(4) + ppLayers(8) + extCount(4) + pad(4) + ppExts(8)
    my $ici = pack('L L Q L L Q L L Q L L Q',
        VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,  # sType
        0,                                        # padding
        0,                                        # pNext
        0,                                        # flags
        0,                                        # padding
        $app_info_ptr,                            # pApplicationInfo
        0,                                        # enabledLayerCount
        0,                                        # padding
        0,                                        # ppEnabledLayerNames
        2,                                        # enabledExtensionCount
        0,                                        # padding
        $exts_ptr                                 # ppEnabledExtensionNames
    );
    
    my $ici_ptr = alloc_struct($ici);
    
    log_msg("  VkInstanceCreateInfo size: " . length($ici) . " bytes");
    log_msg("  ici_ptr: " . hx($ici_ptr));
    
    # Allocate output buffer for instance handle
    my $instance_out_ptr = malloc(8);
    die "Failed to allocate output buffer" unless $instance_out_ptr;
    my $zero = pack('Q', 0);
    memcpy($instance_out_ptr, scalar_to_pointer($zero), 8);
    
    log_msg("  Calling vkCreateInstance...");
    my $res = $vkCreateInstance->($ici_ptr, 0, $instance_out_ptr);
    log_msg("  vkCreateInstance returned: $res");
    vk_check($res, "vkCreateInstance");
    
    my $instance = unpack('Q', buffer_to_scalar($instance_out_ptr, 8));
    return $instance;
}

# ============================================================
# Create Win32 Surface
# ============================================================
sub create_surface {
    my ($instance, $hwnd, $hinst) = @_;
    
    my $func_addr = $vkGetInstanceProcAddr->($instance, "vkCreateWin32SurfaceKHR");
    die "Failed to get vkCreateWin32SurfaceKHR" unless $func_addr;
    
    my $vkCreateWin32SurfaceKHR = $ffi->function($func_addr => ['opaque', 'opaque', 'opaque', 'opaque'] => 'sint32');
    
    # VkWin32SurfaceCreateInfoKHR (40 bytes)
    my $sci = pack('L L Q L L Q Q',
        VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR, 0,  # sType, flags
        0,                                                    # pNext
        0, 0,                                                 # flags, padding
        $hinst,                                               # hinstance
        $hwnd                                                 # hwnd
    );
    
    my $sci_ptr = alloc_struct($sci);
    
    my $surface_out_ptr = malloc(8);
    my $zero = pack('Q', 0);
    memcpy($surface_out_ptr, scalar_to_pointer($zero), 8);
    
    my $res = $vkCreateWin32SurfaceKHR->($instance, $sci_ptr, 0, $surface_out_ptr);
    vk_check($res, "vkCreateWin32SurfaceKHR");
    
    my $surface = unpack('Q', buffer_to_scalar($surface_out_ptr, 8));
    return $surface;
}

# ============================================================
# Pick Physical Device
# ============================================================
sub pick_physical_device {
    my ($instance, $surface) = @_;
    
    # Get vkGetPhysicalDeviceSurfaceSupportKHR
    my $func_addr = $vkGetInstanceProcAddr->($instance, "vkGetPhysicalDeviceSurfaceSupportKHR");
    die "Failed to get vkGetPhysicalDeviceSurfaceSupportKHR" unless $func_addr;
    my $vkGetPhysicalDeviceSurfaceSupportKHR = $ffi->function($func_addr => ['opaque', 'uint32', 'uint64', 'uint32*'] => 'sint32');
    
    my $count = 0;
    my $res = $vkEnumeratePhysicalDevices->($instance, \$count, undef);
    vk_check($res, "vkEnumeratePhysicalDevices(count)");
    die "No Vulkan physical devices found" if $count == 0;
    
    my $devs = "\0" x (8 * $count);  # Array of opaque pointers
    my $devs_ptr = pack_ptr(\$devs);
    $res = $vkEnumeratePhysicalDevices->($instance, \$count, $devs_ptr);
    vk_check($res, "vkEnumeratePhysicalDevices(list)");
    
    for my $i (0 .. $count - 1) {
        my $pd = unpack('Q', substr($devs, $i * 8, 8));
        
        my $qcount = 0;
        $vkGetPhysicalDeviceQueueFamilyProperties->($pd, \$qcount, undef);
        
        my $props = "\0" x (24 * $qcount);  # VkQueueFamilyProperties is 24 bytes
        my $props_ptr = pack_ptr(\$props);
        $vkGetPhysicalDeviceQueueFamilyProperties->($pd, \$qcount, $props_ptr);
        
        my $graphics_idx = -1;
        my $present_idx = -1;
        
        for my $qi (0 .. $qcount - 1) {
            my $qflags = unpack('L', substr($props, $qi * 24, 4));
            
            if ($qflags & VK_QUEUE_GRAPHICS_BIT) {
                $graphics_idx = $qi;
            }
            
            my $supported = 0;
            $res = $vkGetPhysicalDeviceSurfaceSupportKHR->($pd, $qi, $surface, \$supported);
            vk_check($res, "vkGetPhysicalDeviceSurfaceSupportKHR");
            
            if ($supported) {
                $present_idx = $qi;
            }
            
            last if $graphics_idx != -1 && $present_idx != -1;
        }
        
        if ($graphics_idx != -1 && $present_idx != -1) {
            return ($pd, $graphics_idx, $present_idx);
        }
    }
    
    die "No suitable physical device/queue family found";
}

# ============================================================
# Create Device
# ============================================================
sub create_device {
    my ($pd, $graphics_q, $present_q) = @_;
    
    my @unique_q = sort { $a <=> $b } keys %{{ map { $_ => 1 } ($graphics_q, $present_q) }};
    my $q_count = scalar(@unique_q);
    
    # Queue priorities
    my $priorities = pack('f', 1.0);
    my $priorities_ptr = alloc_struct($priorities);
    
    # Build queue create infos (40 bytes each)
    # VkDeviceQueueCreateInfo:
    # sType(4) + pad(4) + pNext(8) + flags(4) + queueFamilyIndex(4) + queueCount(4) + pad(4) + pQueuePriorities(8)
    my $qinfos = '';
    for my $qfi (@unique_q) {
        $qinfos .= pack('L L Q L L L L Q',
            VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,  # sType
            0,                                            # padding
            0,                                            # pNext
            0,                                            # flags
            $qfi,                                         # queueFamilyIndex
            1,                                            # queueCount
            0,                                            # padding
            $priorities_ptr                               # pQueuePriorities
        );
    }
    my $qinfos_ptr = alloc_struct($qinfos);
    
    # Device extensions
    my $swapchain_ext = "VK_KHR_swapchain\0";
    my $swapchain_ext_ptr = pack_ptr(\$swapchain_ext);
    my $dev_exts = pack('Q', $swapchain_ext_ptr);
    my $dev_exts_ptr = alloc_struct($dev_exts);
    
    # VkDeviceCreateInfo (72 bytes)
    # sType(4) + pad(4) + pNext(8) + flags(4) + queueCreateInfoCount(4) + pQueueCreateInfos(8) +
    # enabledLayerCount(4) + pad(4) + ppEnabledLayerNames(8) + 
    # enabledExtensionCount(4) + pad(4) + ppEnabledExtensionNames(8) + pEnabledFeatures(8)
    my $dci = pack('L L Q L L Q L L Q L L Q Q',
        VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,  # sType
        0,                                      # padding
        0,                                      # pNext
        0,                                      # flags
        $q_count,                               # queueCreateInfoCount
        $qinfos_ptr,                            # pQueueCreateInfos
        0,                                      # enabledLayerCount
        0,                                      # padding
        0,                                      # ppEnabledLayerNames
        1,                                      # enabledExtensionCount
        0,                                      # padding
        $dev_exts_ptr,                          # ppEnabledExtensionNames
        0                                       # pEnabledFeatures
    );
    
    my $dci_ptr = alloc_struct($dci);
    
    my $device_out_ptr = malloc(8);
    die "Failed to allocate device output buffer" unless $device_out_ptr;
    my $zero = pack('Q', 0);
    memcpy($device_out_ptr, scalar_to_pointer($zero), 8);
    
    my $res = $vkCreateDevice->($pd, $dci_ptr, 0, $device_out_ptr);
    vk_check($res, "vkCreateDevice");
    my $device = unpack('Q', buffer_to_scalar($device_out_ptr, 8));
    
    my $gq_out_ptr = malloc(8);
    memcpy($gq_out_ptr, scalar_to_pointer($zero), 8);
    $vkGetDeviceQueue->($device, $graphics_q, 0, $gq_out_ptr);
    my $graphics_queue = unpack('Q', buffer_to_scalar($gq_out_ptr, 8));
    
    my $pq_out_ptr = malloc(8);
    memcpy($pq_out_ptr, scalar_to_pointer($zero), 8);
    $vkGetDeviceQueue->($device, $present_q, 0, $pq_out_ptr);
    my $present_queue = unpack('Q', buffer_to_scalar($pq_out_ptr, 8));
    
    return ($device, $graphics_queue, $present_queue);
}

# ============================================================
# Query Swapchain Support
# ============================================================
sub query_swapchain_support {
    my ($instance, $pd, $surface) = @_;
    
    my $func1 = $vkGetInstanceProcAddr->($instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
    my $func2 = $vkGetInstanceProcAddr->($instance, "vkGetPhysicalDeviceSurfaceFormatsKHR");
    my $func3 = $vkGetInstanceProcAddr->($instance, "vkGetPhysicalDeviceSurfacePresentModesKHR");
    
    my $vkGetPhysicalDeviceSurfaceCapabilitiesKHR = $ffi->function($func1 => ['opaque', 'uint64', 'opaque'] => 'sint32');
    my $vkGetPhysicalDeviceSurfaceFormatsKHR = $ffi->function($func2 => ['opaque', 'uint64', 'uint32*', 'opaque'] => 'sint32');
    my $vkGetPhysicalDeviceSurfacePresentModesKHR = $ffi->function($func3 => ['opaque', 'uint64', 'uint32*', 'opaque'] => 'sint32');
    
    # Get capabilities (52 bytes)
    my $caps = "\0" x 52;
    my $caps_ptr = pack_ptr(\$caps);
    my $res = $vkGetPhysicalDeviceSurfaceCapabilitiesKHR->($pd, $surface, $caps_ptr);
    vk_check($res, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
    
    # Get formats
    my $fmt_count = 0;
    $res = $vkGetPhysicalDeviceSurfaceFormatsKHR->($pd, $surface, \$fmt_count, undef);
    vk_check($res, "vkGetPhysicalDeviceSurfaceFormatsKHR(count)");
    
    my $formats = "\0" x (8 * $fmt_count);  # VkSurfaceFormatKHR is 8 bytes
    my $formats_ptr = pack_ptr(\$formats);
    $res = $vkGetPhysicalDeviceSurfaceFormatsKHR->($pd, $surface, \$fmt_count, $formats_ptr);
    vk_check($res, "vkGetPhysicalDeviceSurfaceFormatsKHR(list)");
    
    # Get present modes
    my $pm_count = 0;
    $res = $vkGetPhysicalDeviceSurfacePresentModesKHR->($pd, $surface, \$pm_count, undef);
    vk_check($res, "vkGetPhysicalDeviceSurfacePresentModesKHR(count)");
    
    my $pmodes = "\0" x (4 * $pm_count);
    my $pmodes_ptr = pack_ptr(\$pmodes);
    $res = $vkGetPhysicalDeviceSurfacePresentModesKHR->($pd, $surface, \$pm_count, $pmodes_ptr);
    vk_check($res, "vkGetPhysicalDeviceSurfacePresentModesKHR(list)");
    
    return (\$caps, \$formats, $fmt_count, \$pmodes, $pm_count);
}

# ============================================================
# Choose surface format
# ============================================================
sub choose_surface_format {
    my ($formats_ref, $count) = @_;
    
    for my $i (0 .. $count - 1) {
        my ($format, $colorSpace) = unpack('L L', substr($$formats_ref, $i * 8, 8));
        # VK_FORMAT_B8G8R8A8_SRGB = 50, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR = 0
        if ($format == 50 && $colorSpace == 0) {
            return ($format, $colorSpace);
        }
    }
    
    # Return first format if preferred not found
    my ($format, $colorSpace) = unpack('L L', substr($$formats_ref, 0, 8));
    return ($format, $colorSpace);
}

# ============================================================
# Choose extent
# ============================================================
sub choose_extent {
    my ($hwnd, $caps_ref) = @_;
    
    # Parse capabilities
    my ($minImageCount, $maxImageCount, $cur_w, $cur_h, $min_w, $min_h, $max_w, $max_h) = 
        unpack('L L L L L L L L', substr($$caps_ref, 0, 32));
    
    if ($cur_w != 0xFFFFFFFF) {
        return ($cur_w, $cur_h);
    }
    
    my ($w, $h) = get_client_size($hwnd);
    $w = $min_w if $w < $min_w;
    $w = $max_w if $w > $max_w;
    $h = $min_h if $h < $min_h;
    $h = $max_h if $h > $max_h;
    
    return ($w, $h);
}

# ============================================================
# Device function cache
# ============================================================
my %dev_funcs = ();

sub get_dev_func {
    my ($device, $name, $sig_args, $sig_ret) = @_;
    
    return $dev_funcs{$name} if exists $dev_funcs{$name};
    
    my $addr = $vkGetDeviceProcAddr->($device, $name);
    die "Failed to get $name" unless $addr;
    
    my $func = $ffi->function($addr => $sig_args => $sig_ret);
    $dev_funcs{$name} = $func;
    return $func;
}

# ============================================================
# Create Shader Module
# ============================================================
sub create_shader_module {
    my ($device, $spv) = @_;
    
    my $vkCreateShaderModule = get_dev_func($device, "vkCreateShaderModule",
        ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    
    die "SPIR-V size must be multiple of 4" if (length($spv) % 4) != 0;
    
    my $spv_ptr = alloc_struct($spv);
    
    # VkShaderModuleCreateInfo (40 bytes)
    my $smci = pack('L L Q L L Q Q',
        VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, 0,  # sType, flags
        0,                                                # pNext
        0, 0,                                             # flags, padding
        length($spv),                                     # codeSize
        $spv_ptr                                          # pCode
    );
    
    my $smci_ptr = alloc_struct($smci);
    
    my $module = 0;
    my $res = $vkCreateShaderModule->($device, $smci_ptr, undef, \$module);
    vk_check($res, "vkCreateShaderModule");
    
    return $module;
}

# ============================================================
# Create Swapchain Bundle
# ============================================================
sub create_swapchain_bundle {
    my ($instance, $device, $pd, $surface, $hwnd, $graphics_q, $present_q) = @_;
    
    my %b = ();
    
    # Get device functions
    my $vkCreateSwapchainKHR = get_dev_func($device, "vkCreateSwapchainKHR",
        ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    my $vkGetSwapchainImagesKHR = get_dev_func($device, "vkGetSwapchainImagesKHR",
        ['opaque', 'uint64', 'uint32*', 'opaque'], 'sint32');
    my $vkCreateImageView = get_dev_func($device, "vkCreateImageView",
        ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    my $vkCreateRenderPass = get_dev_func($device, "vkCreateRenderPass",
        ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    my $vkCreatePipelineLayout = get_dev_func($device, "vkCreatePipelineLayout",
        ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    my $vkCreateGraphicsPipelines = get_dev_func($device, "vkCreateGraphicsPipelines",
        ['opaque', 'uint64', 'uint32', 'opaque', 'opaque', 'uint64*'], 'sint32');
    my $vkCreateFramebuffer = get_dev_func($device, "vkCreateFramebuffer",
        ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    my $vkCreateCommandPool = get_dev_func($device, "vkCreateCommandPool",
        ['opaque', 'opaque', 'opaque', 'opaque*'], 'sint32');
    my $vkAllocateCommandBuffers = get_dev_func($device, "vkAllocateCommandBuffers",
        ['opaque', 'opaque', 'opaque'], 'sint32');
    my $vkDestroyShaderModule = get_dev_func($device, "vkDestroyShaderModule",
        ['opaque', 'uint64', 'opaque'], 'void');
    
    # Query swapchain support
    my ($caps_ref, $formats_ref, $fmt_count, $pmodes_ref, $pm_count) = 
        query_swapchain_support($instance, $pd, $surface);
    
    my ($format, $colorSpace) = choose_surface_format($formats_ref, $fmt_count);
    my ($ext_w, $ext_h) = choose_extent($hwnd, $caps_ref);
    
    my ($minImageCount, $maxImageCount) = unpack('L L', substr($$caps_ref, 0, 8));
    my $image_count = $minImageCount + 1;
    $image_count = $maxImageCount if $maxImageCount != 0 && $image_count > $maxImageCount;
    
    my ($currentTransform) = unpack('L', substr($$caps_ref, 36, 4));
    my ($supportedTransforms) = unpack('L', substr($$caps_ref, 32, 4));
    my $preTransform = ($supportedTransforms & $currentTransform) ? $currentTransform : 1;
    
    # Queue family indices
    my $q_indices = pack('L L', $graphics_q, $present_q);
    my $q_indices_ptr;
    my $sharing_mode;
    my $q_count;
    
    if ($graphics_q != $present_q) {
        $sharing_mode = VK_SHARING_MODE_CONCURRENT;
        $q_count = 2;
        $q_indices_ptr = alloc_struct($q_indices);
    } else {
        $sharing_mode = VK_SHARING_MODE_EXCLUSIVE;
        $q_count = 0;
        $q_indices_ptr = 0;
    }
    
    # VkSwapchainCreateInfoKHR (104 bytes)
    # sType(4) + pad(4) + pNext(8) + flags(4) + pad(4) + surface(8) +
    # minImageCount(4) + imageFormat(4) + imageColorSpace(4) + imageExtent(8) +
    # imageArrayLayers(4) + imageUsage(4) + imageSharingMode(4) + queueFamilyIndexCount(4) +
    # pad(4) + pQueueFamilyIndices(8) + preTransform(4) + compositeAlpha(4) +
    # presentMode(4) + clipped(4) + oldSwapchain(8)
    my $sci = pack('L L Q L L Q L L L L L L L L L L Q L L L L Q',
        VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,  # sType
        0,                                              # padding
        0,                                              # pNext
        0,                                              # flags
        0,                                              # padding
        $surface,                                       # surface
        $image_count,                                   # minImageCount
        $format,                                        # imageFormat
        $colorSpace,                                    # imageColorSpace
        $ext_w, $ext_h,                                 # imageExtent
        1,                                              # imageArrayLayers
        VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,           # imageUsage
        $sharing_mode,                                  # imageSharingMode
        $q_count,                                       # queueFamilyIndexCount
        0,                                              # padding
        $q_indices_ptr,                                 # pQueueFamilyIndices
        $preTransform,                                  # preTransform
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,             # compositeAlpha
        VK_PRESENT_MODE_FIFO_KHR,                      # presentMode
        1,                                              # clipped
        0                                               # oldSwapchain
    );
    
    my $sci_ptr = alloc_struct($sci);
    
    my $swapchain = 0;
    my $res = $vkCreateSwapchainKHR->($device, $sci_ptr, undef, \$swapchain);
    vk_check($res, "vkCreateSwapchainKHR");
    
    # Get swapchain images
    my $ic = 0;
    $res = $vkGetSwapchainImagesKHR->($device, $swapchain, \$ic, undef);
    vk_check($res, "vkGetSwapchainImagesKHR(count)");
    
    my $images = "\0" x (8 * $ic);
    my $images_ptr = pack_ptr(\$images);
    $res = $vkGetSwapchainImagesKHR->($device, $swapchain, \$ic, $images_ptr);
    vk_check($res, "vkGetSwapchainImagesKHR(list)");
    
    $b{swapchain} = $swapchain;
    $b{format} = $format;
    $b{extent_w} = $ext_w;
    $b{extent_h} = $ext_h;
    $b{images} = \$images;
    $b{image_count} = $ic;
    
    log_msg("Swapchain created: " . hx($swapchain) . " format=$format extent=${ext_w}x${ext_h} images=$ic");
    
    # Create image views
    my @views = ();
    for my $i (0 .. $ic - 1) {
        my $img = unpack('Q', substr($images, $i * 8, 8));
        
        # VkImageViewCreateInfo (80 bytes)
        my $ivci = pack('L L Q L L Q L L L L L L L L L L L',
            VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, 0,  # sType, flags
            0,                                             # pNext
            0, 0,                                          # flags, padding
            $img,                                          # image
            VK_IMAGE_VIEW_TYPE_2D,                        # viewType
            $format,                                       # format
            0, 0, 0, 0,                                   # components (IDENTITY)
            VK_IMAGE_ASPECT_COLOR_BIT,                    # aspectMask
            0, 1, 0, 1                                    # baseMipLevel, levelCount, baseArrayLayer, layerCount
        );
        
        my $ivci_ptr = alloc_struct($ivci);
        
        my $view = 0;
        $res = $vkCreateImageView->($device, $ivci_ptr, undef, \$view);
        vk_check($res, "vkCreateImageView");
        push @views, $view;
    }
    $b{views} = \@views;
    log_msg("Created $ic swapchain image views");
    
    # Create render pass
    # VkAttachmentDescription (36 bytes)
    my $color_attachment = pack('L L L L L L L L L',
        0,                                    # flags
        $format,                              # format
        VK_SAMPLE_COUNT_1_BIT,               # samples
        VK_ATTACHMENT_LOAD_OP_CLEAR,         # loadOp
        VK_ATTACHMENT_STORE_OP_STORE,        # storeOp
        VK_ATTACHMENT_LOAD_OP_DONT_CARE,     # stencilLoadOp
        VK_ATTACHMENT_STORE_OP_DONT_CARE,    # stencilStoreOp
        VK_IMAGE_LAYOUT_UNDEFINED,           # initialLayout
        VK_IMAGE_LAYOUT_PRESENT_SRC_KHR      # finalLayout
    );
    my $color_attachment_ptr = alloc_struct($color_attachment);
    
    # VkAttachmentReference (8 bytes)
    my $color_ref = pack('L L', 0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);
    my $color_ref_ptr = alloc_struct($color_ref);
    
    # VkSubpassDescription (72 bytes)
    # flags(4) + pipelineBindPoint(4) + inputAttachmentCount(4) + pad(4) + pInputAttachments(8) +
    # colorAttachmentCount(4) + pad(4) + pColorAttachments(8) + pResolveAttachments(8) + 
    # pDepthStencilAttachment(8) + preserveAttachmentCount(4) + pad(4) + pPreserveAttachments(8)
    my $subpass = pack('L L L L Q L L Q Q Q L L Q',
        0,                              # flags
        VK_PIPELINE_BIND_POINT_GRAPHICS, # pipelineBindPoint
        0,                              # inputAttachmentCount
        0,                              # padding
        0,                              # pInputAttachments
        1,                              # colorAttachmentCount
        0,                              # padding
        $color_ref_ptr,                 # pColorAttachments
        0,                              # pResolveAttachments
        0,                              # pDepthStencilAttachment
        0,                              # preserveAttachmentCount
        0,                              # padding
        0                               # pPreserveAttachments
    );
    my $subpass_ptr = alloc_struct($subpass);
    
    # VkRenderPassCreateInfo (64 bytes)
    # sType(4) + pad(4) + pNext(8) + flags(4) + attachmentCount(4) + pAttachments(8) +
    # subpassCount(4) + pad(4) + pSubpasses(8) + dependencyCount(4) + pad(4) + pDependencies(8)
    my $rpci = pack('L L Q L L Q L L Q L L Q',
        VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,  # sType
        0,                                           # padding
        0,                                           # pNext
        0,                                           # flags
        1,                                           # attachmentCount
        $color_attachment_ptr,                       # pAttachments
        1,                                           # subpassCount
        0,                                           # padding
        $subpass_ptr,                                # pSubpasses
        0,                                           # dependencyCount
        0,                                           # padding
        0                                            # pDependencies
    );
    my $rpci_ptr = alloc_struct($rpci);
    
    my $render_pass = 0;
    $res = $vkCreateRenderPass->($device, $rpci_ptr, undef, \$render_pass);
    vk_check($res, "vkCreateRenderPass");
    $b{render_pass} = $render_pass;
    log_msg("RenderPass created: " . hx($render_pass));
    
    # Create shader modules
    my $vert_mod = create_shader_module($device, $vert_spv);
    my $frag_mod = create_shader_module($device, $frag_spv);
    log_msg("Shader modules: vert=" . hx($vert_mod) . " frag=" . hx($frag_mod));
    
    # Create pipeline layout
    # VkPushConstantRange for time and resolution (16 bytes total: float iTime, float padding, vec2 iResolution)
    my $push_constant_range = pack('L L L L',
        VK_SHADER_STAGE_FRAGMENT_BIT,  # stageFlags
        0,                              # offset
        16,                             # size (4 floats: iTime, padding, iResolution.x, iResolution.y)
        0                               # padding
    );
    my $push_constant_range_ptr = alloc_struct($push_constant_range);
    
    # VkPipelineLayoutCreateInfo (48 bytes)
    my $plci = pack('L L Q L L Q L L Q',
        VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,  # sType
        0,                                               # padding
        0,                                               # pNext
        0,                                               # flags
        0,                                               # setLayoutCount
        0,                                               # pSetLayouts
        1,                                               # pushConstantRangeCount
        0,                                               # padding
        $push_constant_range_ptr                         # pPushConstantRanges
    );
    my $plci_ptr = alloc_struct($plci);
    
    my $pipeline_layout = 0;
    $res = $vkCreatePipelineLayout->($device, $plci_ptr, undef, \$pipeline_layout);
    vk_check($res, "vkCreatePipelineLayout");
    $b{pipeline_layout} = $pipeline_layout;
    
    # Create pipeline shader stages
    my $main_name = "main\0";
    my $main_name_ptr = alloc_struct($main_name);
    
    my $vert_stage = pack('L L Q L L Q Q Q',
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, 0,
        0, 0, VK_SHADER_STAGE_VERTEX_BIT, $vert_mod, $main_name_ptr, 0
    );
    my $frag_stage = pack('L L Q L L Q Q Q',
        VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, 0,
        0, 0, VK_SHADER_STAGE_FRAGMENT_BIT, $frag_mod, $main_name_ptr, 0
    );
    my $stages = $vert_stage . $frag_stage;
    my $stages_ptr = alloc_struct($stages);
    
    my $vin = pack('L L Q L L Q L L Q',
        VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,  # sType
        0,                                                           # padding
        0,                                                           # pNext
        0,                                                           # flags
        0,                                                           # vertexBindingDescriptionCount
        0,                                                           # pVertexBindingDescriptions
        0,                                                           # vertexAttributeDescriptionCount
        0,                                                           # padding
        0                                                            # pVertexAttributeDescriptions
    );
    my $vin_ptr = alloc_struct($vin);
    
    my $ia = pack('L L Q L L L L',
        VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,  # sType
        0,                                                             # padding
        0,                                                             # pNext
        0,                                                             # flags
        VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,                          # topology
        0,                                                             # primitiveRestartEnable
        0                                                              # padding to 32 bytes
    );
    my $ia_ptr = alloc_struct($ia);
    
    my $vp = pack('f f f f f f', 0.0, 0.0, $ext_w + 0.0, $ext_h + 0.0, 0.0, 1.0);
    my $vp_ptr = alloc_struct($vp);
    my $sc = pack('l l L L', 0, 0, $ext_w, $ext_h);
    my $sc_ptr = alloc_struct($sc);
    
    # VkPipelineViewportStateCreateInfo (48 bytes)
    my $vp_state = pack('L L Q L L Q L L Q',
        VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,  # sType
        0,                                                       # padding
        0,                                                       # pNext
        0,                                                       # flags
        1,                                                       # viewportCount
        $vp_ptr,                                                 # pViewports
        1,                                                       # scissorCount
        0,                                                       # padding
        $sc_ptr                                                  # pScissors
    );
    my $vp_state_ptr = alloc_struct($vp_state);
    
    # VkPipelineRasterizationStateCreateInfo (64 bytes)
    my $rs = pack('L L Q L L L L L L L L f f f f',
        VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,  # sType
        0,                                                            # padding
        0,                                                            # pNext
        0,                                                            # flags
        0,                                                            # depthClampEnable
        0,                                                            # rasterizerDiscardEnable
        VK_POLYGON_MODE_FILL,                                        # polygonMode
        VK_CULL_MODE_NONE,                                           # cullMode
        VK_FRONT_FACE_COUNTER_CLOCKWISE,                             # frontFace
        0,                                                            # depthBiasEnable
        0,                                                            # padding
        0.0,                                                          # depthBiasConstantFactor
        0.0,                                                          # depthBiasClamp
        0.0,                                                          # depthBiasSlopeFactor
        1.0                                                           # lineWidth
    );
    my $rs_ptr = alloc_struct($rs);
    
    # VkPipelineMultisampleStateCreateInfo (48 bytes)
    my $ms = pack('L L Q L L L f Q L L',
        VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,  # sType
        0,                                                          # padding
        0,                                                          # pNext
        0,                                                          # flags
        VK_SAMPLE_COUNT_1_BIT,                                     # rasterizationSamples
        0,                                                          # sampleShadingEnable
        1.0,                                                        # minSampleShading
        0,                                                          # pSampleMask
        0,                                                          # alphaToCoverageEnable
        0                                                           # alphaToOneEnable
    );
    my $ms_ptr = alloc_struct($ms);
    
    my $cb_attach = pack('L L L L L L L L',
        0, 0, 0, 0, 0, 0, 0,
        VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | 
        VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT
    );
    my $cb_attach_ptr = alloc_struct($cb_attach);
    
    # VkPipelineColorBlendStateCreateInfo (56 bytes)
    my $cb = pack('L L Q L L L L Q f f f f',
        VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,  # sType
        0,                                                          # padding
        0,                                                          # pNext
        0,                                                          # flags
        0,                                                          # logicOpEnable
        0,                                                          # logicOp
        1,                                                          # attachmentCount
        $cb_attach_ptr,                                             # pAttachments
        0.0, 0.0, 0.0, 0.0                                          # blendConstants
    );
    my $cb_ptr = alloc_struct($cb);
    
    my $dyn_states = pack('L L', VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR);
    my $dyn_states_ptr = alloc_struct($dyn_states);
    
    # VkPipelineDynamicStateCreateInfo (32 bytes)
    my $dyn = pack('L L Q L L Q',
        VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,  # sType
        0,                                                      # padding
        0,                                                      # pNext
        0,                                                      # flags
        2,                                                      # dynamicStateCount
        $dyn_states_ptr                                         # pDynamicStates
    );
    my $dyn_ptr = alloc_struct($dyn);
    
    # VkGraphicsPipelineCreateInfo (144 bytes)
    # sType(4) + pad(4) + pNext(8) + flags(4) + stageCount(4) + pStages(8) +
    # 9 more pointers (72) + layout(8) + renderPass(8) + subpass(4) + pad(4) +
    # basePipelineHandle(8) + basePipelineIndex(4) + pad(4)
    my $gpci = pack('L L Q L L Q Q Q Q Q Q Q Q Q Q Q Q L L Q l L',
        VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,  # sType
        0,                                                 # padding
        0,                                                 # pNext
        0,                                                 # flags
        2,                                                 # stageCount
        $stages_ptr,                                       # pStages
        $vin_ptr,                                          # pVertexInputState
        $ia_ptr,                                           # pInputAssemblyState
        0,                                                 # pTessellationState
        $vp_state_ptr,                                     # pViewportState
        $rs_ptr,                                           # pRasterizationState
        $ms_ptr,                                           # pMultisampleState
        0,                                                 # pDepthStencilState
        $cb_ptr,                                           # pColorBlendState
        $dyn_ptr,                                          # pDynamicState
        $pipeline_layout,                                  # layout
        $render_pass,                                      # renderPass
        0,                                                 # subpass
        0,                                                 # padding
        0,                                                 # basePipelineHandle
        -1,                                                # basePipelineIndex
        0                                                  # padding
    );
    my $gpci_ptr = alloc_struct($gpci);
    
    my $pipeline = 0;
    $res = $vkCreateGraphicsPipelines->($device, 0, 1, $gpci_ptr, undef, \$pipeline);
    vk_check($res, "vkCreateGraphicsPipelines");
    $b{pipeline} = $pipeline;
    log_msg("Pipeline created: " . hx($pipeline));
    
    $vkDestroyShaderModule->($device, $vert_mod, undef);
    $vkDestroyShaderModule->($device, $frag_mod, undef);
    
    # Create framebuffers
    my @framebuffers = ();
    for my $i (0 .. $ic - 1) {
        my $attachments = pack('Q', $views[$i]);
        my $attachments_ptr = alloc_struct($attachments);
        
        # VkFramebufferCreateInfo (64 bytes)
        my $fbci = pack('L L Q L L Q L L Q L L L L',
            VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,  # sType
            0,                                           # padding
            0,                                           # pNext
            0,                                           # flags
            0,                                           # padding
            $render_pass,                                # renderPass
            1,                                           # attachmentCount
            0,                                           # padding
            $attachments_ptr,                            # pAttachments
            $ext_w,                                      # width
            $ext_h,                                      # height
            1,                                           # layers
            0                                            # padding
        );
        my $fbci_ptr = alloc_struct($fbci);
        
        my $fb = 0;
        $res = $vkCreateFramebuffer->($device, $fbci_ptr, undef, \$fb);
        vk_check($res, "vkCreateFramebuffer");
        push @framebuffers, $fb;
    }
    $b{framebuffers} = \@framebuffers;
    log_msg("Created $ic framebuffers");
    
    # Create command pool
    my $cpci = pack('L L Q L L',
        VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, 0, 0,
        VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, $graphics_q
    );
    my $cpci_ptr = alloc_struct($cpci);
    
    my $command_pool;
    $res = $vkCreateCommandPool->($device, $cpci_ptr, undef, \$command_pool);
    vk_check($res, "vkCreateCommandPool");
    $b{command_pool} = $command_pool;
    log_msg("CommandPool: " . hx($command_pool));
    
    # Allocate command buffers
    my $cbi = pack('L L Q Q L L',
        VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, 0, 0,
        $command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, $ic
    );
    my $cbi_ptr = alloc_struct($cbi);
    
    my $cbs = "\0" x (8 * $ic);
    my $cbs_ptr = pack_ptr(\$cbs);
    $res = $vkAllocateCommandBuffers->($device, $cbi_ptr, $cbs_ptr);
    vk_check($res, "vkAllocateCommandBuffers");
    
    my @command_buffers = ();
    for my $i (0 .. $ic - 1) {
        push @command_buffers, unpack('Q', substr($cbs, $i * 8, 8));
    }
    $b{command_buffers} = \@command_buffers;
    log_msg("Allocated $ic command buffers");
    
    # Don't record command buffers here - will record dynamically each frame for push constants
    
    return \%b;
}

# ============================================================
# Record Command Buffers
# ============================================================
sub record_command_buffers {
    my ($device, $b) = @_;
    
    my $vkBeginCommandBuffer = get_dev_func($device, "vkBeginCommandBuffer", ['opaque', 'opaque'], 'sint32');
    my $vkEndCommandBuffer = get_dev_func($device, "vkEndCommandBuffer", ['opaque'], 'sint32');
    my $vkCmdBeginRenderPass = get_dev_func($device, "vkCmdBeginRenderPass", ['opaque', 'opaque', 'uint32'], 'void');
    my $vkCmdEndRenderPass = get_dev_func($device, "vkCmdEndRenderPass", ['opaque'], 'void');
    my $vkCmdBindPipeline = get_dev_func($device, "vkCmdBindPipeline", ['opaque', 'uint32', 'uint64'], 'void');
    my $vkCmdDraw = get_dev_func($device, "vkCmdDraw", ['opaque', 'uint32', 'uint32', 'uint32', 'uint32'], 'void');
    my $vkCmdSetViewport = get_dev_func($device, "vkCmdSetViewport", ['opaque', 'uint32', 'uint32', 'opaque'], 'void');
    my $vkCmdSetScissor = get_dev_func($device, "vkCmdSetScissor", ['opaque', 'uint32', 'uint32', 'opaque'], 'void');
    my $vkCmdPushConstants = get_dev_func($device, "vkCmdPushConstants", ['opaque', 'uint64', 'uint32', 'uint32', 'uint32', 'opaque'], 'void');
    
    my $ic = $b->{image_count};
    my $ext_w = $b->{extent_w};
    my $ext_h = $b->{extent_h};
    
    my $clear = pack('f4', 0.05, 0.05, 0.10, 1.0);
    my $clear_ptr = alloc_struct($clear);
    
    for my $i (0 .. $ic - 1) {
        my $cmd = $b->{command_buffers}->[$i];
        my $bi = pack('L L Q L L Q', VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, 0, 0, 0, 0, 0);
        my $bi_ptr = alloc_struct($bi);
        
        my $res = $vkBeginCommandBuffer->($cmd, $bi_ptr);
        vk_check($res, "vkBeginCommandBuffer");
        
        # VkRenderPassBeginInfo (64 bytes)
        my $rpbi = pack('L L Q Q Q l l L L L L Q',
            VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,  # sType
            0,                                          # padding
            0,                                          # pNext
            $b->{render_pass},                          # renderPass
            $b->{framebuffers}->[$i],                   # framebuffer
            0, 0,                                       # renderArea.offset (x, y)
            $ext_w, $ext_h,                             # renderArea.extent (width, height)
            1,                                          # clearValueCount
            0,                                          # padding
            $clear_ptr                                  # pClearValues
        );
        my $rpbi_ptr = alloc_struct($rpbi);
        
        $vkCmdBeginRenderPass->($cmd, $rpbi_ptr, VK_SUBPASS_CONTENTS_INLINE);
        $vkCmdBindPipeline->($cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, $b->{pipeline});
        
        my $vp = pack('f6', 0.0, 0.0, $ext_w + 0.0, $ext_h + 0.0, 0.0, 1.0);
        my $vp_ptr = alloc_struct($vp);
        $vkCmdSetViewport->($cmd, 0, 1, $vp_ptr);
        
        my $sc = pack('l l L L', 0, 0, $ext_w, $ext_h);
        my $sc_ptr = alloc_struct($sc);
        $vkCmdSetScissor->($cmd, 0, 1, $sc_ptr);
        
        $vkCmdDraw->($cmd, 3, 1, 0, 0);
        $vkCmdEndRenderPass->($cmd);
        
        $res = $vkEndCommandBuffer->($cmd);
        vk_check($res, "vkEndCommandBuffer");
    }
    
    log_msg("Command buffers recorded");
}

# ============================================================
# Create Sync Objects
# ============================================================
sub create_sync_objects {
    my ($device, $max_frames) = @_;
    
    my $vkCreateSemaphore = get_dev_func($device, "vkCreateSemaphore", ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    my $vkCreateFence = get_dev_func($device, "vkCreateFence", ['opaque', 'opaque', 'opaque', 'uint64*'], 'sint32');
    
    my %s = (max_frames => $max_frames, image_available => [], render_finished => [], in_flight => []);
    
    my $sci = pack('L L Q L L', VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, 0, 0, 0, 0);
    my $sci_ptr = alloc_struct($sci);
    
    my $fci = pack('L L Q L L', VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, 0, 0, VK_FENCE_CREATE_SIGNALED_BIT, 0);
    my $fci_ptr = alloc_struct($fci);
    
    for my $i (0 .. $max_frames - 1) {
        my ($sem1, $sem2, $fence) = (0, 0, 0);
        vk_check($vkCreateSemaphore->($device, $sci_ptr, undef, \$sem1), "vkCreateSemaphore");
        vk_check($vkCreateSemaphore->($device, $sci_ptr, undef, \$sem2), "vkCreateSemaphore");
        vk_check($vkCreateFence->($device, $fci_ptr, undef, \$fence), "vkCreateFence");
        push @{$s{image_available}}, $sem1;
        push @{$s{render_finished}}, $sem2;
        push @{$s{in_flight}}, $fence;
    }
    
    log_msg("Sync objects created");
    return \%s;
}

# ============================================================
# Destroy Swapchain Bundle
# ============================================================
sub destroy_swapchain_bundle {
    my ($device, $b) = @_;
    
    my $vkDestroyCommandPool = get_dev_func($device, "vkDestroyCommandPool", ['opaque', 'opaque', 'opaque'], 'void');
    my $vkDestroyFramebuffer = get_dev_func($device, "vkDestroyFramebuffer", ['opaque', 'uint64', 'opaque'], 'void');
    my $vkDestroyPipeline = get_dev_func($device, "vkDestroyPipeline", ['opaque', 'uint64', 'opaque'], 'void');
    my $vkDestroyPipelineLayout = get_dev_func($device, "vkDestroyPipelineLayout", ['opaque', 'uint64', 'opaque'], 'void');
    my $vkDestroyRenderPass = get_dev_func($device, "vkDestroyRenderPass", ['opaque', 'uint64', 'opaque'], 'void');
    my $vkDestroyImageView = get_dev_func($device, "vkDestroyImageView", ['opaque', 'uint64', 'opaque'], 'void');
    my $vkDestroySwapchainKHR = get_dev_func($device, "vkDestroySwapchainKHR", ['opaque', 'uint64', 'opaque'], 'void');
    
    $vkDestroyCommandPool->($device, $b->{command_pool}, undef) if $b->{command_pool};
    for my $fb (@{$b->{framebuffers}}) { $vkDestroyFramebuffer->($device, $fb, undef) if $fb; }
    $vkDestroyPipeline->($device, $b->{pipeline}, undef) if $b->{pipeline};
    $vkDestroyPipelineLayout->($device, $b->{pipeline_layout}, undef) if $b->{pipeline_layout};
    $vkDestroyRenderPass->($device, $b->{render_pass}, undef) if $b->{render_pass};
    for my $view (@{$b->{views}}) { $vkDestroyImageView->($device, $view, undef) if $view; }
    $vkDestroySwapchainKHR->($device, $b->{swapchain}, undef) if $b->{swapchain};
}

# ============================================================
# Main
# ============================================================
eval {
    log_msg("=== START ===");
    
    log_msg("STEP: create_window");
    my ($hwnd, $hinst) = create_window("Vulkan 1.4 Raymarching (Perl + shaderc)", 800, 600);
    log_msg("Window created hwnd=" . hx($hwnd) . " hinst=" . hx($hinst));
    
    log_msg("STEP: vkCreateInstance");
    my $instance = create_vk_instance();
    log_msg("vkCreateInstance OK (instance=" . hx($instance) . ")");
    
    log_msg("STEP: vkCreateWin32SurfaceKHR");
    my $surface = create_surface($instance, $hwnd, $hinst);
    log_msg("vkCreateWin32SurfaceKHR OK (surface=" . hx($surface) . ")");
    
    log_msg("STEP: pick_physical_device");
    my ($pd, $graphics_q, $present_q) = pick_physical_device($instance, $surface);
    log_msg("Selected physical device pd=" . hx($pd) . " graphicsQ=$graphics_q presentQ=$present_q");
    
    log_msg("STEP: vkCreateDevice");
    my ($device, $graphics_queue, $present_queue) = create_device($pd, $graphics_q, $present_q);
    log_msg("vkCreateDevice OK (device=" . hx($device) . ")");
    log_msg("Queues: graphics=" . hx($graphics_queue) . " present=" . hx($present_queue));
    
    log_msg("STEP: create_swapchain/pipeline");
    my $bundle = create_swapchain_bundle($instance, $device, $pd, $surface, $hwnd, $graphics_q, $present_q);
    
    log_msg("STEP: create_sync_objects");
    my $sync = create_sync_objects($device, 2);
    
    my $vkAcquireNextImageKHR = get_dev_func($device, "vkAcquireNextImageKHR",
        ['opaque', 'uint64', 'uint64', 'uint64', 'uint64', 'uint32*'], 'sint32');
    my $vkQueueSubmit = get_dev_func($device, "vkQueueSubmit", ['opaque', 'uint32', 'opaque', 'uint64'], 'sint32');
    my $vkQueuePresentKHR = get_dev_func($device, "vkQueuePresentKHR", ['opaque', 'opaque'], 'sint32');
    my $vkWaitForFences = get_dev_func($device, "vkWaitForFences", ['opaque', 'uint32', 'opaque', 'uint32', 'uint64'], 'sint32');
    my $vkResetFences = get_dev_func($device, "vkResetFences", ['opaque', 'uint32', 'opaque'], 'sint32');
    
    my $frame = 0;
    my $start_time = time();
    log_msg("STEP: entering main loop (close the window to exit)");
    
    my $msg = "\0" x 48;
    my $running = 1;
    
    while ($running) {
        unless ($IsWindow->Call($hwnd)) {
            log_msg("Window closed by user");
            $running = 0;
            last;
        }
        
        if ($PeekMessageW->Call($msg, 0, 0, 0, PM_REMOVE)) {
            my $msg_id = unpack('L', substr($msg, 8, 4));
            if ($msg_id == WM_QUIT || $msg_id == WM_CLOSE || $msg_id == WM_DESTROY) {
                $running = 0;
            } else {
                $TranslateMessage->Call($msg);
                $DispatchMessageW->Call($msg);
            }
        } else {
            my $cur = $frame % $sync->{max_frames};
            
            my $fence = pack('Q', $sync->{in_flight}->[$cur]);
            my $fence_ptr = pack_ptr(\$fence);
            vk_check($vkWaitForFences->($device, 1, $fence_ptr, 1, $UINT64_MAX), "vkWaitForFences");
            vk_check($vkResetFences->($device, 1, $fence_ptr), "vkResetFences");
            
            my $image_index = 0;
            my $res = $vkAcquireNextImageKHR->($device, $bundle->{swapchain}, $UINT64_MAX,
                $sync->{image_available}->[$cur], 0, \$image_index);
            
            if ($res == VK_ERROR_OUT_OF_DATE_KHR) {
                $vkDeviceWaitIdle->($device);
                destroy_swapchain_bundle($device, $bundle);
                $bundle = create_swapchain_bundle($instance, $device, $pd, $surface, $hwnd, $graphics_q, $present_q);
                next;
            } elsif ($res != VK_SUCCESS && $res != VK_SUBOPTIMAL_KHR) {
                die "vkAcquireNextImageKHR failed: $res";
            }
            
            # Record command buffer dynamically each frame for push constants
            my $cmd_buf = $bundle->{command_buffers}->[$image_index];
            my $elapsed_time = time() - $start_time;
            my $ext_w = $bundle->{extent_w};
            my $ext_h = $bundle->{extent_h};
            
            # Reset and begin command buffer
            my $vkResetCommandBuffer = get_dev_func($device, "vkResetCommandBuffer", ['opaque', 'uint32'], 'sint32');
            my $vkBeginCommandBuffer = get_dev_func($device, "vkBeginCommandBuffer", ['opaque', 'opaque'], 'sint32');
            my $vkEndCommandBuffer = get_dev_func($device, "vkEndCommandBuffer", ['opaque'], 'sint32');
            my $vkCmdBeginRenderPass = get_dev_func($device, "vkCmdBeginRenderPass", ['opaque', 'opaque', 'uint32'], 'void');
            my $vkCmdEndRenderPass = get_dev_func($device, "vkCmdEndRenderPass", ['opaque'], 'void');
            my $vkCmdBindPipeline = get_dev_func($device, "vkCmdBindPipeline", ['opaque', 'uint32', 'uint64'], 'void');
            my $vkCmdPushConstants = get_dev_func($device, "vkCmdPushConstants", ['opaque', 'uint64', 'uint32', 'uint32', 'uint32', 'opaque'], 'void');
            my $vkCmdDraw = get_dev_func($device, "vkCmdDraw", ['opaque', 'uint32', 'uint32', 'uint32', 'uint32'], 'void');
            my $vkCmdSetViewport = get_dev_func($device, "vkCmdSetViewport", ['opaque', 'uint32', 'uint32', 'opaque'], 'void');
            my $vkCmdSetScissor = get_dev_func($device, "vkCmdSetScissor", ['opaque', 'uint32', 'uint32', 'opaque'], 'void');
            
            vk_check($vkResetCommandBuffer->($cmd_buf, 0), "vkResetCommandBuffer");
            
            my $bi = pack('L L Q L L Q', VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, 0, 0, 0, 0, 0);
            my $bi_ptr = alloc_struct($bi);
            vk_check($vkBeginCommandBuffer->($cmd_buf, $bi_ptr), "vkBeginCommandBuffer");
            
            # Begin render pass
            my $clear = pack('f4', 0.05, 0.05, 0.10, 1.0);
            my $clear_ptr = alloc_struct($clear);
            my $rpbi = pack('L L Q Q Q l l L L L L Q',
                VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
                0, 0,
                $bundle->{render_pass},
                $bundle->{framebuffers}->[$image_index],
                0, 0, $ext_w, $ext_h,
                1, 0, $clear_ptr
            );
            my $rpbi_ptr = alloc_struct($rpbi);
            
            $vkCmdBeginRenderPass->($cmd_buf, $rpbi_ptr, VK_SUBPASS_CONTENTS_INLINE);
            $vkCmdBindPipeline->($cmd_buf, VK_PIPELINE_BIND_POINT_GRAPHICS, $bundle->{pipeline});
            
            # Set viewport and scissor
            my $vp = pack('f6', 0.0, 0.0, $ext_w + 0.0, $ext_h + 0.0, 0.0, 1.0);
            my $vp_ptr = alloc_struct($vp);
            $vkCmdSetViewport->($cmd_buf, 0, 1, $vp_ptr);
            
            my $sc = pack('l l L L', 0, 0, $ext_w, $ext_h);
            my $sc_ptr = alloc_struct($sc);
            $vkCmdSetScissor->($cmd_buf, 0, 1, $sc_ptr);
            
            # Push constants: iTime, padding, iResolution.x, iResolution.y (16 bytes total)
            my $push_data = pack('f f f f', $elapsed_time, 0.0, $ext_w + 0.0, $ext_h + 0.0);
            my $push_data_ptr = alloc_struct($push_data);
            $vkCmdPushConstants->($cmd_buf, $bundle->{pipeline_layout}, VK_SHADER_STAGE_FRAGMENT_BIT, 0, 16, $push_data_ptr);
            
            # Draw fullscreen triangle
            $vkCmdDraw->($cmd_buf, 3, 1, 0, 0);
            $vkCmdEndRenderPass->($cmd_buf);
            
            vk_check($vkEndCommandBuffer->($cmd_buf), "vkEndCommandBuffer");
            
            my $wait_sems = pack('Q', $sync->{image_available}->[$cur]);
            my $wait_sems_ptr = alloc_struct($wait_sems);
            my $signal_sems = pack('Q', $sync->{render_finished}->[$cur]);
            my $signal_sems_ptr = alloc_struct($signal_sems);
            my $wait_stages = pack('L', VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
            my $wait_stages_ptr = alloc_struct($wait_stages);
            my $cmd = pack('Q', $cmd_buf);
            my $cmd_ptr = alloc_struct($cmd);
            
            # VkSubmitInfo (72 bytes)
            my $submit = pack('L L Q L L Q Q L L Q L L Q',
                VK_STRUCTURE_TYPE_SUBMIT_INFO,      # sType
                0,                                   # padding
                0,                                   # pNext
                1,                                   # waitSemaphoreCount
                0,                                   # padding
                $wait_sems_ptr,                      # pWaitSemaphores
                $wait_stages_ptr,                    # pWaitDstStageMask
                1,                                   # commandBufferCount
                0,                                   # padding
                $cmd_ptr,                            # pCommandBuffers
                1,                                   # signalSemaphoreCount
                0,                                   # padding
                $signal_sems_ptr                     # pSignalSemaphores
            );
            my $submit_ptr = alloc_struct($submit);
            
            vk_check($vkQueueSubmit->($graphics_queue, 1, $submit_ptr, $sync->{in_flight}->[$cur]), "vkQueueSubmit");
            
            my $swapchains = pack('Q', $bundle->{swapchain});
            my $swapchains_ptr = alloc_struct($swapchains);
            my $indices = pack('L', $image_index);
            my $indices_ptr = alloc_struct($indices);
            
            # VkPresentInfoKHR (64 bytes)
            my $present = pack('L L Q L L Q L L Q Q Q',
                VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,  # sType
                0,                                    # padding
                0,                                    # pNext
                1,                                    # waitSemaphoreCount
                0,                                    # padding
                $signal_sems_ptr,                     # pWaitSemaphores
                1,                                    # swapchainCount
                0,                                    # padding
                $swapchains_ptr,                      # pSwapchains
                $indices_ptr,                         # pImageIndices
                0                                     # pResults
            );
            my $present_ptr = alloc_struct($present);
            
            my $pres_res = $vkQueuePresentKHR->($present_queue, $present_ptr);
            if ($pres_res == VK_ERROR_OUT_OF_DATE_KHR || $pres_res == VK_SUBOPTIMAL_KHR) {
                $vkDeviceWaitIdle->($device);
                destroy_swapchain_bundle($device, $bundle);
                $bundle = create_swapchain_bundle($instance, $device, $pd, $surface, $hwnd, $graphics_q, $present_q);
            } elsif ($pres_res != VK_SUCCESS) {
                die "vkQueuePresentKHR failed: $pres_res";
            }
            
            $frame++;
            $Sleep->Call(1);
        }
    }
    
    log_msg("Main loop ended; waiting device idle...");
    $vkDeviceWaitIdle->($device);
    
    destroy_swapchain_bundle($device, $bundle);
    
    my $vkDestroySemaphore = get_dev_func($device, "vkDestroySemaphore", ['opaque', 'uint64', 'opaque'], 'void');
    my $vkDestroyFence = get_dev_func($device, "vkDestroyFence", ['opaque', 'uint64', 'opaque'], 'void');
    
    for my $i (0 .. $sync->{max_frames} - 1) {
        $vkDestroySemaphore->($device, $sync->{image_available}->[$i], undef);
        $vkDestroySemaphore->($device, $sync->{render_finished}->[$i], undef);
        $vkDestroyFence->($device, $sync->{in_flight}->[$i], undef);
    }
    
    my $vkDestroySurfaceKHR_addr = $vkGetInstanceProcAddr->($instance, "vkDestroySurfaceKHR");
    my $vkDestroySurfaceKHR = $ffi->function($vkDestroySurfaceKHR_addr => ['opaque', 'uint64', 'opaque'], 'void');
    
    $vkDestroyDevice->($device, undef);
    $vkDestroySurfaceKHR->($instance, $surface, undef);
    $vkDestroyInstance->($instance, undef);
    
    log_msg("=== END ===");
};

if ($@) {
    print "Error: $@\n";
}

print "\nDone.\n";
