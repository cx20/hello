#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Vulkan 1.4 Compute Harmonograph (Windows, Ruby, Fiddle)
#
# A compute shader calculates harmonograph positions & colours
# into SSBOs, which the vertex shader reads via gl_VertexIndex.
# Animated every frame by updating a uniform buffer.
#
# Requirements (Windows x64):
# - Ruby 3.x x64
# - Vulkan runtime (vulkan-1.dll)
# - Vulkan SDK (for shaderc_shared.dll OR put shaderc_shared.dll next to this script)

require 'fiddle'
require 'fiddle/import'
require 'pathname'
require 'time'

# ============================================================
# Logging
# ============================================================
$T0 = Time.now
def log_msg(msg)
  dt = Time.now - $T0
  printf("[%8.3f] %s\n", dt, msg)
end

def hx(v)
  return "(null)" if v.nil? || v == 0
  sprintf("0x%016X", v.to_i)
end

# ============================================================
# Memory helpers (keep alive)
# ============================================================
$keep = []

def cstr(str)
  s = str.to_s + "\0"
  p = Fiddle::Pointer.malloc(s.bytesize)
  p[0, s.bytesize] = s
  $keep << p
  p.to_i
end

def blob(bytes)
  p = Fiddle::Pointer.malloc(bytes.bytesize)
  p[0, bytes.bytesize] = bytes
  $keep << p
  p.to_i
end

def u32(v) v & 0xFFFFFFFF end
def vk_make_version(major, minor, patch)
  (major << 22) | (minor << 12) | patch
end

# ============================================================
# Win32 (minimal)
# ============================================================
module Win
  extend Fiddle::Importer
  dlload 'user32.dll', 'kernel32.dll'
  typealias 'HWND', 'void*'
  typealias 'HINSTANCE', 'void*'
  typealias 'HICON', 'void*'
  typealias 'HCURSOR', 'void*'
  typealias 'HBRUSH', 'void*'
  typealias 'LRESULT', 'intptr_t'
  typealias 'WPARAM', 'uintptr_t'
  typealias 'LPARAM', 'intptr_t'
  typealias 'UINT', 'unsigned int'
  typealias 'DWORD', 'unsigned long'
  typealias 'BOOL', 'int'

  WS_OVERLAPPEDWINDOW = 0x00CF0000
  CS_HREDRAW = 0x0002
  CS_VREDRAW = 0x0001
  CW_USEDEFAULT = -2147483648
  SW_SHOW = 5

  WM_DESTROY = 0x0002
  WM_CLOSE   = 0x0010
  PM_REMOVE  = 0x0001

  RECT = struct(['long left', 'long top', 'long right', 'long bottom'])

  WNDCLASSEXA = struct([
    'UINT cbSize',
    'UINT style',
    'void* lpfnWndProc',
    'int cbClsExtra',
    'int cbWndExtra',
    'HINSTANCE hInstance',
    'HICON hIcon',
    'HCURSOR hCursor',
    'HBRUSH hbrBackground',
    'char* lpszMenuName',
    'char* lpszClassName',
    'HICON hIconSm'
  ])

  extern 'unsigned short RegisterClassExA(void*)'
  extern 'HWND CreateWindowExA(DWORD, const char*, const char*, DWORD, int, int, int, int, HWND, void*, HINSTANCE, void*)'
  extern 'BOOL ShowWindow(HWND, int)'
  extern 'BOOL UpdateWindow(HWND)'
  extern 'BOOL PeekMessageA(void*, HWND, UINT, UINT, UINT)'
  extern 'BOOL TranslateMessage(void*)'
  extern 'LRESULT DispatchMessageA(void*)'
  extern 'void PostQuitMessage(int)'
  extern 'LRESULT DefWindowProcA(HWND, UINT, WPARAM, LPARAM)'
  extern 'BOOL GetClientRect(HWND, void*)'
  extern 'HINSTANCE GetModuleHandleA(const char*)'
  extern 'DWORD GetLastError()'
  extern 'void Sleep(DWORD)'
end

$should_quit = false

WndProc = Fiddle::Closure::BlockCaller.new(
  Fiddle::TYPE_INTPTR_T,
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINTPTR_T, Fiddle::TYPE_INTPTR_T]
) do |hwnd, msg, wparam, lparam|
  case msg
  when Win::WM_CLOSE, Win::WM_DESTROY
    $should_quit = true
    Win.PostQuitMessage(0)
    0
  else
    Win.DefWindowProcA(hwnd, msg, wparam, lparam)
  end
end

def create_window(title, w, h)
  hinst = Win.GetModuleHandleA(nil)
  klass = "RubyVulkanHarmonograph"

  wc = Win::WNDCLASSEXA.malloc
  wc.cbSize = Win::WNDCLASSEXA.size
  wc.style = Win::CS_HREDRAW | Win::CS_VREDRAW
  wc.lpfnWndProc = Fiddle::Pointer[WndProc.to_i]
  wc.cbClsExtra = 0
  wc.cbWndExtra = 0
  wc.hInstance = Fiddle::Pointer[hinst]
  wc.hIcon = nil
  wc.hCursor = nil
  wc.hbrBackground = nil
  wc.lpszMenuName = nil
  wc.lpszClassName = Fiddle::Pointer[cstr(klass)]
  wc.hIconSm = nil

  atom = Win.RegisterClassExA(wc)
  raise "RegisterClassExA failed: #{Win.GetLastError()}" if atom == 0

  hwnd = Win.CreateWindowExA(
    0, klass, title,
    Win::WS_OVERLAPPEDWINDOW,
    Win::CW_USEDEFAULT, Win::CW_USEDEFAULT, w, h,
    nil, nil, Fiddle::Pointer[hinst], nil
  )
  raise "CreateWindowExA failed: #{Win.GetLastError()}" if hwnd.to_i == 0

  Win.ShowWindow(hwnd, Win::SW_SHOW)
  Win.UpdateWindow(hwnd)
  [hwnd.to_i, hinst.to_i]
end

def pump_messages
  msg = "\0" * 48
  while Win.PeekMessageA(msg, nil, 0, 0, Win::PM_REMOVE) != 0
    Win.TranslateMessage(msg)
    Win.DispatchMessageA(msg)
  end
  !$should_quit
end

def get_client_size(hwnd)
  r = "\0" * Win::RECT.size
  Win.GetClientRect(Fiddle::Pointer[hwnd], r)
  left, top, right, bottom = r.unpack('l4')
  w = [right - left, 1].max
  h = [bottom - top, 1].max
  [w, h]
end

# ============================================================
# shaderc (GLSL -> SPIR-V)
# ============================================================
class ShaderCompiler
  VERTEX   = 0
  FRAGMENT = 1
  COMPUTE  = 2
  STATUS_SUCCESS = 0

  def initialize(dll_name = "shaderc_shared.dll")
    path = resolve(dll_name)
    log_msg("Loading shaderc: #{path}")
    @lib = Fiddle.dlopen(path)
    @compiler_init = Fiddle::Function.new(@lib['shaderc_compiler_initialize'], [], Fiddle::TYPE_VOIDP)
    @compiler_release = Fiddle::Function.new(@lib['shaderc_compiler_release'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    @opts_init = Fiddle::Function.new(@lib['shaderc_compile_options_initialize'], [], Fiddle::TYPE_VOIDP)
    @opts_release = Fiddle::Function.new(@lib['shaderc_compile_options_release'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    @opts_set_opt = Fiddle::Function.new(@lib['shaderc_compile_options_set_optimization_level'], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_VOID)
    @compile = Fiddle::Function.new(@lib['shaderc_compile_into_spv'],
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
      Fiddle::TYPE_VOIDP)
    @res_release = Fiddle::Function.new(@lib['shaderc_result_release'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)
    @res_len = Fiddle::Function.new(@lib['shaderc_result_get_length'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_SIZE_T)
    @res_bytes = Fiddle::Function.new(@lib['shaderc_result_get_bytes'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
    @res_status = Fiddle::Function.new(@lib['shaderc_result_get_compilation_status'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT)
    @res_err = Fiddle::Function.new(@lib['shaderc_result_get_error_message'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)
  end

  def compile_glsl(src, kind, filename)
    compiler = @compiler_init.call
    raise "shaderc_compiler_initialize failed" if compiler == 0
    opts = @opts_init.call
    raise "shaderc_compile_options_initialize failed" if opts == 0
    @opts_set_opt.call(opts, 2)

    src_u8 = src.encode('utf-8')
    p_src = blob(src_u8)
    p_file = cstr(filename)
    p_entry = cstr("main")
    res = @compile.call(compiler, p_src, src_u8.bytesize, kind, p_file, p_entry, opts)
    raise "shaderc_compile_into_spv returned NULL" if res == 0

    st = @res_status.call(res)
    if st != STATUS_SUCCESS
      ep = @res_err.call(res)
      msg = (ep && ep != 0) ? Fiddle::Pointer.new(ep).to_s : "(no message)"
      @res_release.call(res)
      @opts_release.call(opts)
      @compiler_release.call(compiler)
      raise "shaderc failed (#{st}): #{msg}"
    end

    n = @res_len.call(res)
    bp = @res_bytes.call(res)
    spv = Fiddle::Pointer.new(bp).to_s(n)

    @res_release.call(res)
    @opts_release.call(opts)
    @compiler_release.call(compiler)
    spv
  end

  private
  def resolve(name)
    here = Pathname.new(__FILE__).dirname
    local = (here / name).to_s
    return local if File.exist?(local)
    return File.expand_path(name) if File.exist?(name)
    sdk = ENV['VULKAN_SDK']
    if sdk
      p = File.join(sdk, 'Bin', name)
      return p if File.exist?(p)
    end
    name
  end
end

# ============================================================
# Shader sources (embedded)
# ============================================================
COMP_SRC = <<~'GLSL'
  #version 450
  layout(local_size_x = 256) in;

  layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
  layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

  layout(std140, binding = 2) uniform Params {
      uint  max_num;
      float dt, scale, pad0;
      float A1, f1, p1, d1;
      float A2, f2, p2, d2;
      float A3, f3, p3, d3;
      float A4, f4, p4, d4;
  } u;

  vec3 hsv2rgb(float h, float s, float v) {
      float c = v * s;
      float hp = h / 60.0;
      float x = c * (1.0 - abs(mod(hp, 2.0) - 1.0));
      vec3 rgb;
      if      (hp < 1.0) rgb = vec3(c, x, 0.0);
      else if (hp < 2.0) rgb = vec3(x, c, 0.0);
      else if (hp < 3.0) rgb = vec3(0.0, c, x);
      else if (hp < 4.0) rgb = vec3(0.0, x, c);
      else if (hp < 5.0) rgb = vec3(x, 0.0, c);
      else               rgb = vec3(c, 0.0, x);
      return rgb + (v - c);
  }

  void main() {
      uint i = gl_GlobalInvocationID.x;
      if (i >= u.max_num) return;

      float t = float(i) * u.dt;
      float x = u.A1 * sin(t * u.f1 + u.p1) * exp(-u.d1 * t)
              + u.A3 * sin(t * u.f3 + u.p3) * exp(-u.d3 * t);
      float y = u.A2 * sin(t * u.f2 + u.p2) * exp(-u.d2 * t)
              + u.A4 * sin(t * u.f4 + u.p4) * exp(-u.d4 * t);

      pos[i] = vec4(x * u.scale, y * u.scale, 0.0, 1.0);

      float hue  = mod(float(i) / float(u.max_num) * 360.0 + t * 10.0, 360.0);
      float fade = exp(-u.d1 * t * 0.3);
      col[i] = vec4(hsv2rgb(hue, 0.8, fade), fade);
  }
GLSL

VERT_SRC = <<~'GLSL'
  #version 450
  layout(std430, binding = 0) readonly buffer Positions { vec4 pos[]; };
  layout(std430, binding = 1) readonly buffer Colors    { vec4 col[]; };

  layout(location = 0) out vec4 fragColor;

  void main() {
      gl_Position = pos[gl_VertexIndex];
      fragColor   = col[gl_VertexIndex];
      gl_PointSize = 1.0;
  }
GLSL

FRAG_SRC = <<~'GLSL'
  #version 450
  layout(location = 0) in  vec4 fragColor;
  layout(location = 0) out vec4 outColor;

  void main() {
      outColor = fragColor;
  }
GLSL

# ============================================================
# Vulkan loader
# ============================================================
log_msg("Loading vulkan-1.dll...")
VK = Fiddle.dlopen('vulkan-1.dll')

def vk_fn(name, ret, args)
  Fiddle::Function.new(VK[name], args, ret)
rescue => e
  raise "Failed to load #{name}: #{e.message}"
end

vkGetInstanceProcAddr = vk_fn('vkGetInstanceProcAddr', Fiddle::TYPE_VOIDP, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetDeviceProcAddr   = vk_fn('vkGetDeviceProcAddr',   Fiddle::TYPE_VOIDP, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])

def vk_inst_fn(vkGetInstanceProcAddr, instance, name, ret, args)
  p_name = cstr(name)
  fp = vkGetInstanceProcAddr.call(instance, p_name)
  raise "vkGetInstanceProcAddr returned NULL for #{name}" if fp.nil? || fp == 0
  Fiddle::Function.new(fp, args, ret)
end

def vk_dev_fn(vkGetDeviceProcAddr, device, name, ret, args)
  p_name = cstr(name)
  fp = vkGetDeviceProcAddr.call(device, p_name)
  raise "vkGetDeviceProcAddr returned NULL for #{name}" if fp.nil? || fp == 0
  Fiddle::Function.new(fp, args, ret)
end

# ============================================================
# Vulkan constants
# ============================================================
VK_SUCCESS = 0
VK_TRUE = 1
VK_FALSE = 0
VK_SUBOPTIMAL_KHR = 1000001003
VK_ERROR_OUT_OF_DATE_KHR = -1000001004

VK_STRUCTURE_TYPE_APPLICATION_INFO                       = 0
VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO                   = 1
VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO               = 2
VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO                     = 3
VK_STRUCTURE_TYPE_SUBMIT_INFO                            = 4
VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO                   = 5
VK_STRUCTURE_TYPE_FENCE_CREATE_INFO                      = 8
VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO                  = 9
VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO                     = 12
VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO                 = 15
VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO              = 16
VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO      = 18
VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO    = 22
VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO          = 28
VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO           = 29
VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO            = 30
VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO      = 32
VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO            = 33
VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO           = 34
VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET                   = 35
VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO                = 37
VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO                = 38
VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO               = 39
VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO           = 40
VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO               = 42
VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO                 = 43
VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER                  = 44
VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR          = 1000009000
VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR              = 1000001000
VK_STRUCTURE_TYPE_PRESENT_INFO_KHR                       = 1000001002

VK_QUEUE_GRAPHICS_BIT = 0x00000001
VK_QUEUE_COMPUTE_BIT  = 0x00000002
VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002
VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0

VK_IMAGE_ASPECT_COLOR_BIT = 0x1
VK_IMAGE_VIEW_TYPE_2D = 1

VK_FORMAT_B8G8R8A8_UNORM = 44
VK_FORMAT_B8G8R8A8_SRGB  = 50

VK_COLORSPACE_SRGB_NONLINEAR_KHR = 0

VK_IMAGE_LAYOUT_UNDEFINED = 0
VK_IMAGE_LAYOUT_PRESENT_SRC_KHR = 1000001002
VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2

VK_ATTACHMENT_LOAD_OP_CLEAR = 1
VK_ATTACHMENT_STORE_OP_STORE = 0
VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
VK_ATTACHMENT_STORE_OP_DONT_CARE = 1

VK_PIPELINE_BIND_POINT_GRAPHICS = 0
VK_PIPELINE_BIND_POINT_COMPUTE  = 1
VK_PRIMITIVE_TOPOLOGY_LINE_STRIP = 2
VK_POLYGON_MODE_FILL = 0
VK_CULL_MODE_NONE = 0
VK_FRONT_FACE_COUNTER_CLOCKWISE = 1
VK_SAMPLE_COUNT_1_BIT = 1

VK_COLOR_COMPONENT_R_BIT = 0x1
VK_COLOR_COMPONENT_G_BIT = 0x2
VK_COLOR_COMPONENT_B_BIT = 0x4
VK_COLOR_COMPONENT_A_BIT = 0x8

VK_SHADER_STAGE_VERTEX_BIT   = 0x00000001
VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010
VK_SHADER_STAGE_COMPUTE_BIT  = 0x00000020

VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT          = 0x00000800
VK_PIPELINE_STAGE_VERTEX_SHADER_BIT           = 0x00000008
VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT  = 0x00000400

VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010
VK_SHARING_MODE_EXCLUSIVE = 0
VK_PRESENT_MODE_FIFO_KHR = 2
VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001
VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001

VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001

VK_BUFFER_USAGE_STORAGE_BUFFER_BIT = 0x00000020
VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT = 0x00000010

VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT  = 0x01
VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT  = 0x02
VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x04

VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER = 6
VK_DESCRIPTOR_TYPE_STORAGE_BUFFER = 7

VK_ACCESS_SHADER_READ_BIT  = 0x00000020
VK_ACCESS_SHADER_WRITE_BIT = 0x00000040

VK_QUEUE_FAMILY_IGNORED = 0xFFFFFFFF
VK_WHOLE_SIZE           = 0xFFFFFFFFFFFFFFFF

VERTEX_COUNT = 500_000

def vk_check(res, what)
  raise "#{what} failed: VkResult=#{res}" if res != VK_SUCCESS
end

# ============================================================
# Struct builders (x64 packing!)
# ============================================================
def vk_application_info
  p_app = cstr("RubyVulkanHarmonograph")
  p_eng = cstr("none")
  data = [
    VK_STRUCTURE_TYPE_APPLICATION_INFO,
    0, p_app, 1, p_eng, 1,
    vk_make_version(1,4,0)
  ].pack('L x4 Q Q L x4 Q L L')
  blob(data)
end

def vk_instance_create_info(p_app_info)
  ext = [cstr("VK_KHR_surface"), cstr("VK_KHR_win32_surface")]
  ext_arr = blob(ext.pack('Q*'))
  data = [
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    0, 0, p_app_info,
    0, 0,
    ext.length, ext_arr
  ].pack('L x4 Q L x4 Q L x4 Q L x4 Q')
  blob(data)
end

def vk_win32_surface_ci(hinst, hwnd)
  data = [
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    0, 0, hinst, hwnd
  ].pack('L x4 Q L x4 Q Q')
  blob(data)
end

def vk_device_queue_ci(qfam, p_prio)
  data = [
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    0, 0, qfam, 1, p_prio
  ].pack('L x4 Q L L L x4 Q')
  blob(data)
end

def vk_device_ci(p_queue_ci)
  ext = [cstr("VK_KHR_swapchain")]
  ext_arr = blob(ext.pack('Q*'))
  data = [
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    0, 0, 1, p_queue_ci,
    0, 0,
    ext.length, ext_arr,
    0
  ].pack('L x4 Q L L Q L x4 Q L x4 Q Q')
  blob(data)
end

def vk_swapchain_ci(surface, fmt, colorspace, w, h, min_images, qfam)
  extent64 = (u32(h) << 32) | u32(w)
  data = [
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    0, 0, surface,
    min_images, fmt, colorspace, extent64,
    1, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
    VK_SHARING_MODE_EXCLUSIVE, 0, 0,
    VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    VK_PRESENT_MODE_FIFO_KHR, VK_TRUE,
    0
  ].pack('L x4 Q L x4 Q L L L Q L L L L x4 Q L L L L x4 Q')
  blob(data)
end

def vk_image_view_ci(image, fmt)
  components = [0,0,0,0].pack('L4')
  subrange   = [VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1].pack('L5') + ("\0"*4)
  data = [
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    0, 0, image,
    VK_IMAGE_VIEW_TYPE_2D, fmt
  ].pack('L x4 Q L x4 Q L L') + components + subrange
  blob(data)
end

def vk_shader_module_ci(code_bytes)
  p_code = blob(code_bytes)
  data = [
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    0, 0, code_bytes.bytesize, p_code
  ].pack('L x4 Q L x4 Q Q')
  blob(data)
end

def vk_render_pass_ci(fmt)
  attach_data = [
    0, fmt, VK_SAMPLE_COUNT_1_BIT,
    VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE,
    VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE,
    VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR
  ].pack('L9')
  p_attach = blob(attach_data)

  aref_data = [0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL].pack('L2')
  p_aref = blob(aref_data)

  subpass_data = [0, VK_PIPELINE_BIND_POINT_GRAPHICS, 0].pack('L3')
  subpass_data += "\0" * 4
  subpass_data += [0].pack('Q')
  subpass_data += [1].pack('L')
  subpass_data += "\0" * 4
  subpass_data += [p_aref].pack('Q')
  subpass_data += [0].pack('Q')
  subpass_data += [0].pack('Q')
  subpass_data += [0].pack('L')
  subpass_data += "\0" * 4
  subpass_data += [0].pack('Q')
  p_subpass = blob(subpass_data)

  rpci_data = [VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO].pack('L')
  rpci_data += "\0" * 4
  rpci_data += [0].pack('Q')
  rpci_data += [0, 1].pack('L2')
  rpci_data += [p_attach].pack('Q')
  rpci_data += [1].pack('L')
  rpci_data += "\0" * 4
  rpci_data += [p_subpass].pack('Q')
  rpci_data += [0].pack('L')
  rpci_data += "\0" * 4
  rpci_data += [0].pack('Q')
  blob(rpci_data)
end

# VkPipelineLayoutCreateInfo (48 bytes)
# sType(4) pad(4) pNext(8) flags(4) setLayoutCount(4)
# pSetLayouts(8) pushConstantRangeCount(4) pad(4) pPushConstantRanges(8)
def vk_pipeline_layout_ci_with_desc(desc_set_layout)
  p_layouts = blob([desc_set_layout].pack('Q'))
  data = [
    VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    0,   # pNext
    0,   # flags
    1,   # setLayoutCount
    p_layouts,
    0,   # pushConstantRangeCount
    0    # pPushConstantRanges
  ].pack('L x4 Q L L Q L x4 Q')
  blob(data)
end

def vk_framebuffer_ci(render_pass, view, w, h)
  p_attachments = blob([view].pack('Q'))
  data = [
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
    0, 0, render_pass,
    1, p_attachments,
    w, h, 1
  ].pack('L x4 Q L x4 Q L x4 Q L L L x4')
  blob(data)
end

def vk_command_pool_ci(qfam)
  data = [VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, 0,
          VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, qfam].pack('L x4 Q L L')
  blob(data)
end

def vk_command_buffer_alloc_ci(pool, count)
  data = [VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, 0,
          pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, count].pack('L x4 Q Q L L')
  blob(data)
end

def vk_command_buffer_begin_ci
  data = [VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO, 0, 0, 0].pack('L x4 Q L x4 Q')
  blob(data)
end

def vk_render_pass_begin_ci(render_pass, fb, w, h, clear_rgba)
  clear = clear_rgba.pack('f4')
  p_clear = blob(clear)
  render_area = [0,0, w, h].pack('l2L2')
  data = [VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, 0,
          render_pass, fb].pack('L x4 Q Q Q') +
         render_area +
         [1].pack('L') + ("\0"*4) + [p_clear].pack('Q')
  blob(data)
end

# ============================================================
# Buffer / Memory / Descriptor struct builders
# ============================================================

# VkBufferCreateInfo (56 bytes)
def vk_buffer_ci(size, usage)
  [VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
   0, 0, size, usage,
   VK_SHARING_MODE_EXCLUSIVE, 0, 0
  ].pack('L x4 Q L x4 Q L L L x4 Q')
end

# VkMemoryAllocateInfo (32 bytes)
def vk_memory_alloc_info(size, type_index)
  [VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
   0, size, type_index
  ].pack('L x4 Q Q L x4')
end

def find_memory_type(mem_props, type_bits, desired_flags)
  type_count = mem_props[0, 4].unpack1('L')
  type_count.times do |i|
    if (type_bits & (1 << i)) != 0
      # memoryTypes[i] is at offset 4 + i*8, propertyFlags is first uint32
      prop_flags = mem_props[4 + i * 8, 4].unpack1('L')
      if (prop_flags & desired_flags) == desired_flags
        return i
      end
    end
  end
  raise "Failed to find suitable memory type (bits=#{type_bits.to_s(16)}, flags=#{desired_flags.to_s(16)})"
end

# VkDescriptorSetLayoutBinding (24 bytes) = L L L L Q
def vk_desc_binding(binding, desc_type, count, stage_flags)
  [binding, desc_type, count, stage_flags, 0].pack('L L L L Q')
end

# VkDescriptorSetLayoutCreateInfo (32 bytes)
def vk_desc_set_layout_ci(p_bindings, binding_count)
  [VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
   0, 0, binding_count, p_bindings
  ].pack('L x4 Q L L Q')
end

# VkDescriptorPoolSize (8 bytes) = L L
# VkDescriptorPoolCreateInfo (40 bytes)
def vk_desc_pool_ci(max_sets, p_sizes, size_count)
  [VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
   0, 0, max_sets, size_count, p_sizes
  ].pack('L x4 Q L L L x4 Q')
end

# VkDescriptorSetAllocateInfo (40 bytes)
def vk_desc_set_alloc_info(pool, p_layouts, count)
  [VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
   0, pool, count, p_layouts
  ].pack('L x4 Q Q L x4 Q')
end

# VkDescriptorBufferInfo (24 bytes) = Q Q Q
def vk_desc_buffer_info(buffer, offset, range)
  [buffer, offset, range].pack('Q Q Q')
end

# VkWriteDescriptorSet (64 bytes)
def vk_write_desc_set(dst_set, binding, desc_type, p_buf_info)
  [VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
   0,          # pNext
   dst_set,    # dstSet
   binding,    # dstBinding
   0,          # dstArrayElement
   1,          # descriptorCount
   desc_type,  # descriptorType
   0,          # pImageInfo
   p_buf_info, # pBufferInfo
   0           # pTexelBufferView
  ].pack('L x4 Q Q L L L L Q Q Q')
end

# VkBufferMemoryBarrier (56 bytes)
def vk_buffer_barrier(buffer, size)
  [VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER,
   0,                       # pNext
   VK_ACCESS_SHADER_WRITE_BIT,
   VK_ACCESS_SHADER_READ_BIT,
   VK_QUEUE_FAMILY_IGNORED,
   VK_QUEUE_FAMILY_IGNORED,
   buffer, 0, size
  ].pack('L x4 Q L L L L Q Q Q')
end

# ============================================================
# Main
# ============================================================
puts "=== Ruby Vulkan 1.4 Compute Harmonograph ==="

log_msg("STEP: shaderc compile")
shaderc = ShaderCompiler.new
comp_spv = shaderc.compile_glsl(COMP_SRC, ShaderCompiler::COMPUTE, "hello.comp")
vert_spv = shaderc.compile_glsl(VERT_SRC, ShaderCompiler::VERTEX, "hello.vert")
frag_spv = shaderc.compile_glsl(FRAG_SRC, ShaderCompiler::FRAGMENT, "hello.frag")
log_msg("shaderc OK: comp #{comp_spv.bytesize}B, vert #{vert_spv.bytesize}B, frag #{frag_spv.bytesize}B")

log_msg("STEP: create window")
hwnd, hinst = create_window("Vulkan 1.4 Compute Harmonograph (Ruby)", 800, 600)
w, h = get_client_size(hwnd)
log_msg("Window: hwnd=#{hx(hwnd)} size=#{w}x#{h}")

# Global functions
vkCreateInstance = vk_fn('vkCreateInstance', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkEnumeratePhysicalDevices = vk_fn('vkEnumeratePhysicalDevices', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetPhysicalDeviceQueueFamilyProperties = vk_fn('vkGetPhysicalDeviceQueueFamilyProperties', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetPhysicalDeviceMemoryProperties = vk_fn('vkGetPhysicalDeviceMemoryProperties', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateDevice = vk_fn('vkCreateDevice', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])

log_msg("STEP: vkCreateInstance")
p_app = vk_application_info
p_ici = vk_instance_create_info(p_app)
out = "\0"*8
vk_check(vkCreateInstance.call(p_ici, 0, out), "vkCreateInstance")
instance = out.unpack1('Q')
log_msg("Instance: #{hx(instance)}")

# Instance functions
vkDestroyInstance = vk_inst_fn(vkGetInstanceProcAddr, instance, 'vkDestroyInstance', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateWin32SurfaceKHR = vk_inst_fn(vkGetInstanceProcAddr, instance, 'vkCreateWin32SurfaceKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroySurfaceKHR = vk_inst_fn(vkGetInstanceProcAddr, instance, 'vkDestroySurfaceKHR', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetPhysicalDeviceSurfaceSupportKHR = vk_inst_fn(vkGetInstanceProcAddr, instance, 'vkGetPhysicalDeviceSurfaceSupportKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetPhysicalDeviceSurfaceCapabilitiesKHR = vk_inst_fn(vkGetInstanceProcAddr, instance, 'vkGetPhysicalDeviceSurfaceCapabilitiesKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetPhysicalDeviceSurfaceFormatsKHR = vk_inst_fn(vkGetInstanceProcAddr, instance, 'vkGetPhysicalDeviceSurfaceFormatsKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])

log_msg("STEP: vkEnumeratePhysicalDevices")
cnt = "\0"*4
vk_check(vkEnumeratePhysicalDevices.call(instance, cnt, 0), "vkEnumeratePhysicalDevices(count)")
n = cnt.unpack1('L')
raise "No physical devices" if n == 0
list = "\0"*(8*n)
vk_check(vkEnumeratePhysicalDevices.call(instance, cnt, list), "vkEnumeratePhysicalDevices(list)")
phys = list.unpack('Q*')[0]
log_msg("PhysicalDevice: #{hx(phys)} (count=#{n})")

log_msg("STEP: create surface")
p_sci = vk_win32_surface_ci(hinst, hwnd)
surf_out = "\0"*8
vk_check(vkCreateWin32SurfaceKHR.call(instance, p_sci, 0, surf_out), "vkCreateWin32SurfaceKHR")
surface = surf_out.unpack1('Q')
log_msg("Surface: #{hx(surface)}")

log_msg("STEP: pick queue family (graphics+compute+present)")
qcnt = "\0"*4
vkGetPhysicalDeviceQueueFamilyProperties.call(phys, qcnt, 0)
qcount = qcnt.unpack1('L')
props = "\0"*(qcount*24)
vkGetPhysicalDeviceQueueFamilyProperties.call(phys, qcnt, props)

gfx_q = nil
present_q = nil

qcount.times do |i|
  flags = props[i*24, 4].unpack1('L')
  has_graphics = (flags & VK_QUEUE_GRAPHICS_BIT) != 0
  has_compute  = (flags & VK_QUEUE_COMPUTE_BIT) != 0

  sup = "\0"*4
  vk_check(vkGetPhysicalDeviceSurfaceSupportKHR.call(phys, i, surface, sup), "vkGetPhysicalDeviceSurfaceSupportKHR")
  present = sup.unpack1('L') != 0

  if has_graphics && has_compute
    gfx_q ||= i
    present_q ||= i if present
  end
  if present && present_q.nil?
    present_q = i
  end
end

raise "No graphics+compute queue" if gfx_q.nil?
raise "No present queue" if present_q.nil?
log_msg("QueueFamily: graphics+compute=#{gfx_q} present=#{present_q}")

log_msg("STEP: get memory properties")
# VkPhysicalDeviceMemoryProperties is 520 bytes
mem_props = "\0" * 520
vkGetPhysicalDeviceMemoryProperties.call(phys, mem_props)

log_msg("STEP: vkCreateDevice")
prio = blob([1.0].pack('f'))
p_qci = vk_device_queue_ci(gfx_q, prio)
p_dci = vk_device_ci(p_qci)
dev_out = "\0"*8
vk_check(vkCreateDevice.call(phys, p_dci, 0, dev_out), "vkCreateDevice")
device = dev_out.unpack1('Q')
log_msg("Device: #{hx(device)}")

# Device functions
vkDestroyDevice = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyDevice', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetDeviceQueue = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkGetDeviceQueue', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
vkCreateSwapchainKHR = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateSwapchainKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroySwapchainKHR = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroySwapchainKHR', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetSwapchainImagesKHR = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkGetSwapchainImagesKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateImageView = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateImageView', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyImageView = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyImageView', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateShaderModule = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateShaderModule', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyShaderModule = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyShaderModule', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateRenderPass = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateRenderPass', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyRenderPass = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyRenderPass', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreatePipelineLayout = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreatePipelineLayout', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyPipelineLayout = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyPipelineLayout', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateGraphicsPipelines = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateGraphicsPipelines', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateComputePipelines = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateComputePipelines', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyPipeline = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyPipeline', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateFramebuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateFramebuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyFramebuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyFramebuffer', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateCommandPool = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateCommandPool', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyCommandPool = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyCommandPool', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkAllocateCommandBuffers = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkAllocateCommandBuffers', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkBeginCommandBuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkBeginCommandBuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkEndCommandBuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkEndCommandBuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP])
vkResetCommandBuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkResetCommandBuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT])
vkCmdBeginRenderPass = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdBeginRenderPass', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT])
vkCmdEndRenderPass = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdEndRenderPass', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP])
vkCmdBindPipeline = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdBindPipeline', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
vkCmdDraw = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdDraw', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
vkCmdBindDescriptorSets = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdBindDescriptorSets', Fiddle::TYPE_VOID,
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
vkCmdDispatch = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdDispatch', Fiddle::TYPE_VOID,
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])
vkCmdPipelineBarrier = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdPipelineBarrier', Fiddle::TYPE_VOID,
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT,
   Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP,
   Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])

vkCreateSemaphore = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateSemaphore', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroySemaphore = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroySemaphore', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateFence = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateFence', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyFence = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyFence', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkWaitForFences = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkWaitForFences', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_ULONG_LONG])
vkResetFences = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkResetFences', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])

vkAcquireNextImageKHR = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkAcquireNextImageKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG_LONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkQueueSubmit = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkQueueSubmit', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkQueuePresentKHR = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkQueuePresentKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDeviceWaitIdle = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDeviceWaitIdle', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP])

# Buffer / memory functions
vkCreateBuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateBuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyBuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyBuffer', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetBufferMemoryRequirements = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkGetBufferMemoryRequirements', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkAllocateMemory = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkAllocateMemory', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkFreeMemory = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkFreeMemory', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkBindBufferMemory = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkBindBufferMemory', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG_LONG])
vkMapMemory = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkMapMemory', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG_LONG, Fiddle::TYPE_ULONG_LONG, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
vkUnmapMemory = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkUnmapMemory', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])

# Descriptor functions
vkCreateDescriptorSetLayout = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateDescriptorSetLayout', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyDescriptorSetLayout = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyDescriptorSetLayout', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateDescriptorPool = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateDescriptorPool', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyDescriptorPool = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyDescriptorPool', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkAllocateDescriptorSets = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkAllocateDescriptorSets', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkUpdateDescriptorSets = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkUpdateDescriptorSets', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])

# Get queues
q_out = "\0"*8
vkGetDeviceQueue.call(device, gfx_q, 0, q_out)
graphics_queue = q_out.unpack1('Q')
vkGetDeviceQueue.call(device, present_q, 0, q_out)
present_queue = q_out.unpack1('Q')
log_msg("Queues: graphics=#{hx(graphics_queue)} present=#{hx(present_queue)}")

# ============================================================
# Swapchain
# ============================================================
log_msg("STEP: surface formats / capabilities")
caps = "\0"*52
vk_check(vkGetPhysicalDeviceSurfaceCapabilitiesKHR.call(phys, surface, caps), "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")
min_img, max_img = caps.unpack('L2')
cur_w, cur_h = caps[8,8].unpack('L2')
if cur_w == 0xFFFFFFFF
  cur_w, cur_h = get_client_size(hwnd)
end
min_images = [min_img + 1, 2].max
min_images = max_img if max_img != 0 && min_images > max_img

fmt_count = "\0"*4
vk_check(vkGetPhysicalDeviceSurfaceFormatsKHR.call(phys, surface, fmt_count, 0), "vkGetPhysicalDeviceSurfaceFormatsKHR(count)")
nf = fmt_count.unpack1('L')
fmts = "\0"*(nf*8)
vk_check(vkGetPhysicalDeviceSurfaceFormatsKHR.call(phys, surface, fmt_count, fmts), "vkGetPhysicalDeviceSurfaceFormatsKHR(list)")
chosen_fmt = nil
chosen_cs = VK_COLORSPACE_SRGB_NONLINEAR_KHR
nf.times do |i|
  f, cs = fmts[i*8,8].unpack('L2')
  if f == VK_FORMAT_B8G8R8A8_SRGB || f == VK_FORMAT_B8G8R8A8_UNORM
    chosen_fmt = f
    chosen_cs = cs
    break
  end
end
if chosen_fmt.nil?
  chosen_fmt, chosen_cs = fmts[0,8].unpack('L2')
end
log_msg("Swapchain: extent=#{cur_w}x#{cur_h} minImages=#{min_images} format=#{chosen_fmt}")

log_msg("STEP: vkCreateSwapchainKHR")
p_swp = vk_swapchain_ci(surface, chosen_fmt, chosen_cs, cur_w, cur_h, min_images, gfx_q)
sw_out = "\0"*8
vk_check(vkCreateSwapchainKHR.call(device, p_swp, 0, sw_out), "vkCreateSwapchainKHR")
swapchain = sw_out.unpack1('Q')

log_msg("STEP: vkGetSwapchainImagesKHR")
ic = "\0"*4
vk_check(vkGetSwapchainImagesKHR.call(device, swapchain, ic, 0), "vkGetSwapchainImagesKHR(count)")
image_count = ic.unpack1('L')
imgs = "\0"*(image_count*8)
vk_check(vkGetSwapchainImagesKHR.call(device, swapchain, ic, imgs), "vkGetSwapchainImagesKHR(list)")
images = imgs.unpack('Q*')
log_msg("Swapchain images: #{image_count}")

# Create image views
views = []
images.each do |img|
  p_iv = vk_image_view_ci(img, chosen_fmt)
  outv = "\0"*8
  vk_check(vkCreateImageView.call(device, p_iv, 0, outv), "vkCreateImageView")
  views << outv.unpack1('Q')
end

# ============================================================
# Render pass
# ============================================================
log_msg("STEP: render pass")
p_rpci = vk_render_pass_ci(chosen_fmt)
rp_out = "\0"*8
vk_check(vkCreateRenderPass.call(device, p_rpci, 0, rp_out), "vkCreateRenderPass")
render_pass = rp_out.unpack1('Q')
log_msg("Render pass: #{hx(render_pass)}")

# ============================================================
# Shader modules
# ============================================================
log_msg("STEP: shader modules")
p_csm = vk_shader_module_ci(comp_spv)
csm_out = "\0"*8
vk_check(vkCreateShaderModule.call(device, p_csm, 0, csm_out), "vkCreateShaderModule(comp)")
comp_mod = csm_out.unpack1('Q')

p_vsm = vk_shader_module_ci(vert_spv)
vsm_out = "\0"*8
vk_check(vkCreateShaderModule.call(device, p_vsm, 0, vsm_out), "vkCreateShaderModule(vert)")
vert_mod = vsm_out.unpack1('Q')

p_fsm = vk_shader_module_ci(frag_spv)
fsm_out = "\0"*8
vk_check(vkCreateShaderModule.call(device, p_fsm, 0, fsm_out), "vkCreateShaderModule(frag)")
frag_mod = fsm_out.unpack1('Q')
log_msg("Shader modules: comp=#{hx(comp_mod)} vert=#{hx(vert_mod)} frag=#{hx(frag_mod)}")

# ============================================================
# Buffers (positions SSBO, colors SSBO, UBO)
# ============================================================
log_msg("STEP: create buffers")

pos_size = VERTEX_COUNT * 16   # vec4 = 16 bytes
col_size = VERTEX_COUNT * 16
ubo_size = 80                  # 20 floats (uint32 + 19 floats) = 80 bytes

def create_buffer(vkCreateBuffer, vkGetBufferMemoryRequirements, vkAllocateMemory, vkBindBufferMemory,
                  device, mem_props, size, usage, mem_flags)
  ci = vk_buffer_ci(size, usage)
  buf_out = "\0"*8
  vk_check(vkCreateBuffer.call(device, blob(ci), 0, buf_out), "vkCreateBuffer")
  buffer = buf_out.unpack1('Q')

  # VkMemoryRequirements: size(8) alignment(8) memoryTypeBits(4) pad(4) = 24 bytes
  req = "\0"*24
  vkGetBufferMemoryRequirements.call(device, buffer, req)
  alloc_size = req[0,8].unpack1('Q')
  mem_type_bits = req[16,4].unpack1('L')

  type_idx = find_memory_type(mem_props, mem_type_bits, mem_flags)
  ai = vk_memory_alloc_info(alloc_size, type_idx)
  mem_out = "\0"*8
  vk_check(vkAllocateMemory.call(device, blob(ai), 0, mem_out), "vkAllocateMemory")
  memory = mem_out.unpack1('Q')

  vk_check(vkBindBufferMemory.call(device, buffer, memory, 0), "vkBindBufferMemory")
  [buffer, memory]
end

pos_buffer, pos_memory = create_buffer(
  vkCreateBuffer, vkGetBufferMemoryRequirements, vkAllocateMemory, vkBindBufferMemory,
  device, mem_props, pos_size, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)

col_buffer, col_memory = create_buffer(
  vkCreateBuffer, vkGetBufferMemoryRequirements, vkAllocateMemory, vkBindBufferMemory,
  device, mem_props, col_size, VK_BUFFER_USAGE_STORAGE_BUFFER_BIT, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)

ubo_buffer, ubo_memory = create_buffer(
  vkCreateBuffer, vkGetBufferMemoryRequirements, vkAllocateMemory, vkBindBufferMemory,
  device, mem_props, ubo_size, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
  VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)

log_msg("Buffers: pos=#{hx(pos_buffer)} col=#{hx(col_buffer)} ubo=#{hx(ubo_buffer)}")

# ============================================================
# Descriptor set layout, pool, set
# ============================================================
log_msg("STEP: descriptor set")

stage_comp_vert = VK_SHADER_STAGE_COMPUTE_BIT | VK_SHADER_STAGE_VERTEX_BIT

bindings_data = vk_desc_binding(0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, stage_comp_vert) +
                vk_desc_binding(1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, stage_comp_vert) +
                vk_desc_binding(2, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT)
p_bindings = blob(bindings_data)

dsl_ci = vk_desc_set_layout_ci(p_bindings, 3)
dsl_out = "\0"*8
vk_check(vkCreateDescriptorSetLayout.call(device, blob(dsl_ci), 0, dsl_out), "vkCreateDescriptorSetLayout")
desc_set_layout = dsl_out.unpack1('Q')
log_msg("DescriptorSetLayout: #{hx(desc_set_layout)}")

# Pool
pool_sizes = [VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 2,
              VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 1].pack('L4')
dp_ci = vk_desc_pool_ci(1, blob(pool_sizes), 2)
dp_out = "\0"*8
vk_check(vkCreateDescriptorPool.call(device, blob(dp_ci), 0, dp_out), "vkCreateDescriptorPool")
desc_pool = dp_out.unpack1('Q')

# Allocate
p_dsl = blob([desc_set_layout].pack('Q'))
dsai = vk_desc_set_alloc_info(desc_pool, p_dsl, 1)
ds_out = "\0"*8
vk_check(vkAllocateDescriptorSets.call(device, blob(dsai), ds_out), "vkAllocateDescriptorSets")
desc_set = ds_out.unpack1('Q')

# Write
pos_bi = vk_desc_buffer_info(pos_buffer, 0, pos_size)
col_bi = vk_desc_buffer_info(col_buffer, 0, col_size)
ubo_bi = vk_desc_buffer_info(ubo_buffer, 0, ubo_size)

writes = vk_write_desc_set(desc_set, 0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, blob(pos_bi)) +
         vk_write_desc_set(desc_set, 1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, blob(col_bi)) +
         vk_write_desc_set(desc_set, 2, VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, blob(ubo_bi))
vkUpdateDescriptorSets.call(device, 3, blob(writes), 0, 0)
log_msg("Descriptor set updated")

# ============================================================
# Pipeline layout (shared by compute and graphics)
# ============================================================
p_plci = vk_pipeline_layout_ci_with_desc(desc_set_layout)
pl_out = "\0"*8
vk_check(vkCreatePipelineLayout.call(device, p_plci, 0, pl_out), "vkCreatePipelineLayout")
pipeline_layout = pl_out.unpack1('Q')
log_msg("Pipeline layout: #{hx(pipeline_layout)}")

# ============================================================
# Compute pipeline
# ============================================================
log_msg("STEP: compute pipeline")
p_entry = cstr("main")

# VkComputePipelineCreateInfo (96 bytes):
# sType(4) pad(4) pNext(8) flags(4) pad(4)
# stage{ sType(4) pad(4) pNext(8) flags(4) stage(4) module(8) pName(8) pSpec(8) } = 48
# layout(8) basePipelineHandle(8) basePipelineIndex(4) pad(4)
compute_ci = [VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO, 0, 0].pack('L x4 Q L x4') +
             [VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, 0, 0,
              VK_SHADER_STAGE_COMPUTE_BIT, comp_mod, p_entry, 0].pack('L x4 Q L L Q Q Q') +
             [pipeline_layout, 0, -1].pack('Q Q l x4')
comp_pipe_out = "\0"*8
vk_check(vkCreateComputePipelines.call(device, 0, 1, blob(compute_ci), 0, comp_pipe_out), "vkCreateComputePipelines")
compute_pipeline = comp_pipe_out.unpack1('Q')
log_msg("Compute pipeline: #{hx(compute_pipeline)}")

# ============================================================
# Graphics pipeline (LINE_STRIP, fixed viewport/scissor)
# ============================================================
log_msg("STEP: graphics pipeline")

def shader_stage_ci_data(stage, module_handle)
  entry = cstr("main")
  [VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
   0, 0, stage, module_handle, entry, 0].pack('L x4 Q L L Q Q Q')
end

stages_data = shader_stage_ci_data(VK_SHADER_STAGE_VERTEX_BIT, vert_mod) +
              shader_stage_ci_data(VK_SHADER_STAGE_FRAGMENT_BIT, frag_mod)
stages = blob(stages_data)

# VkPipelineVertexInputStateCreateInfo (48 bytes) - no vertex input
vi = [VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 + [0].pack('Q') +
  [0, 0].pack('L2') + [0].pack('Q') +
  [0].pack('L') + "\0" * 4 + [0].pack('Q')
p_vi = blob(vi)

# VkPipelineInputAssemblyStateCreateInfo (32 bytes) - LINE_STRIP
ia = [VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 + [0].pack('Q') +
  [0, VK_PRIMITIVE_TOPOLOGY_LINE_STRIP, VK_FALSE].pack('L3') +
  "\0" * 4
p_ia = blob(ia)

# VkViewport + VkRect2D
viewport = [0.0, 0.0, cur_w.to_f, cur_h.to_f, 0.0, 1.0].pack('f6')
scissor  = [0,0, cur_w, cur_h].pack('l2L2')
p_viewport = blob(viewport)
p_scissor  = blob(scissor)

# VkPipelineViewportStateCreateInfo (48 bytes)
vp = [VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 + [0].pack('Q') +
  [0, 1].pack('L2') + [p_viewport].pack('Q') +
  [1].pack('L') + "\0" * 4 + [p_scissor].pack('Q')
p_vp = blob(vp)

# VkPipelineRasterizationStateCreateInfo (64 bytes)
rast = [VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO].pack('L') +
       "\0" * 4 + [0].pack('Q') +
       [0, VK_FALSE, VK_FALSE,
  VK_POLYGON_MODE_FILL, VK_CULL_MODE_NONE, VK_FRONT_FACE_COUNTER_CLOCKWISE,
  VK_FALSE].pack('L7') +
       [0.0, 0.0, 0.0, 1.0].pack('f4') +
       "\0" * 4
p_rs = blob(rast)

# VkPipelineMultisampleStateCreateInfo (48 bytes)
ms = [VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 + [0].pack('Q') +
  [0, VK_SAMPLE_COUNT_1_BIT, VK_FALSE].pack('L3') +
  [1.0].pack('f') + [0].pack('Q') +
  [VK_FALSE, VK_FALSE].pack('L2')
p_ms = blob(ms)

# VkPipelineColorBlendAttachmentState (32 bytes)
cba = [VK_FALSE, 1, 0, 0, 1, 0, 0,
  (VK_COLOR_COMPONENT_R_BIT|VK_COLOR_COMPONENT_G_BIT|VK_COLOR_COMPONENT_B_BIT|VK_COLOR_COMPONENT_A_BIT)].pack('L8')
p_cba = blob(cba)

# VkPipelineColorBlendStateCreateInfo (56 bytes)
cb = [VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 + [0].pack('Q') +
  [0, VK_FALSE, 0, 1].pack('L4') +
  [p_cba].pack('Q') +
  [0.0, 0.0, 0.0, 0.0].pack('f4')
p_cb = blob(cb)

# VkGraphicsPipelineCreateInfo (144 bytes)
gp = [VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO].pack('L') +
     "\0" * 4 +
     [0].pack('Q') +
     [0, 2].pack('L2') +
     [stages].pack('Q') +
     [p_vi, p_ia, 0, p_vp, p_rs, p_ms, 0, p_cb, 0, pipeline_layout, render_pass].pack('Q11') +
     [0].pack('L') +
     "\0" * 4 +
     [0].pack('Q') +
     [0].pack('l') +
     "\0" * 4
p_gp = blob(gp)

pipe_out = "\0"*8
vk_check(vkCreateGraphicsPipelines.call(device, 0, 1, p_gp, 0, pipe_out), "vkCreateGraphicsPipelines")
graphics_pipeline = pipe_out.unpack1('Q')
log_msg("Graphics pipeline: #{hx(graphics_pipeline)} (LINE_STRIP)")

# ============================================================
# Framebuffers
# ============================================================
framebuffers = []
views.each do |view|
  p_fbci = vk_framebuffer_ci(render_pass, view, cur_w, cur_h)
  outfb = "\0"*8
  vk_check(vkCreateFramebuffer.call(device, p_fbci, 0, outfb), "vkCreateFramebuffer")
  framebuffers << outfb.unpack1('Q')
end

# ============================================================
# Command pool & buffers
# ============================================================
log_msg("STEP: command buffers")
p_cpci = vk_command_pool_ci(gfx_q)
cp_out = "\0"*8
vk_check(vkCreateCommandPool.call(device, p_cpci, 0, cp_out), "vkCreateCommandPool")
cmd_pool = cp_out.unpack1('Q')

p_cbai = vk_command_buffer_alloc_ci(cmd_pool, image_count)
cbs = "\0"*(8*image_count)
vk_check(vkAllocateCommandBuffers.call(device, p_cbai, cbs), "vkAllocateCommandBuffers")
cmd_buffers = cbs.unpack('Q*')

# ============================================================
# Sync objects
# ============================================================
log_msg("STEP: sync objects")
MAX_FRAMES = 2
image_available = []
render_finished = []
in_flight = []

sem_ci = [VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, 0, 0].pack('L x4 Q L')
fence_ci_signaled = [VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, 0, VK_FENCE_CREATE_SIGNALED_BIT].pack('L x4 Q L')

MAX_FRAMES.times do
  s1 = "\0"*8; s2 = "\0"*8; f = "\0"*8
  vk_check(vkCreateSemaphore.call(device, blob(sem_ci), 0, s1), "vkCreateSemaphore")
  vk_check(vkCreateSemaphore.call(device, blob(sem_ci), 0, s2), "vkCreateSemaphore")
  vk_check(vkCreateFence.call(device, blob(fence_ci_signaled), 0, f), "vkCreateFence")
  image_available << s1.unpack1('Q')
  render_finished << s2.unpack1('Q')
  in_flight << f.unpack1('Q')
end

# ============================================================
# Harmonograph parameters (UBO)
# ============================================================
# 20 values: max_num(uint32), dt, scale, pad0, A1,f1,p1,d1, A2,f2,p2,d2, A3,f3,p3,d3, A4,f4,p4,d4
max_num = VERTEX_COUNT
dt      = 0.001
scale   = 0.02
pad0    = 0.0
a1 = 50.0; f1 = 2.0; p1 = 1.0/16.0;  d1 = 0.02
a2 = 50.0; f2 = 2.0; p2 = 3.0/2.0;   d2 = 0.0315
a3 = 50.0; f3 = 2.0; p3 = 13.0/15.0; d3 = 0.02
a4 = 50.0; f4 = 2.0; p4 = 1.0;       d4 = 0.02

anim_time = 0.0
groups_x = (VERTEX_COUNT + 255) / 256

# Pre-build pipeline barrier data (2 * VkBufferMemoryBarrier = 2 * 56 bytes)
pos_barrier = vk_buffer_barrier(pos_buffer, pos_size)
col_barrier = vk_buffer_barrier(col_buffer, col_size)
p_barriers = blob(pos_barrier + col_barrier)

# Descriptor set pointer for binding
p_desc_set = blob([desc_set].pack('Q'))

# ============================================================
# Main loop
# ============================================================
log_msg("STEP: main loop (close window to exit)")
frame = 0
while pump_messages
  cur = frame % MAX_FRAMES

  # Wait for fence
  fences = [in_flight[cur]].pack('Q')
  vk_check(vkWaitForFences.call(device, 1, fences, VK_TRUE, 1_000_000_000), "vkWaitForFences")
  vk_check(vkResetFences.call(device, 1, fences), "vkResetFences")

  # Acquire
  img_index = "\0"*4
  res = vkAcquireNextImageKHR.call(device, swapchain, 1_000_000_000, image_available[cur], 0, img_index)
  raise "vkAcquireNextImageKHR failed: VkResult=#{res}" unless res == VK_SUCCESS || res == VK_SUBOPTIMAL_KHR
  idx = img_index.unpack1('L')

  # Animate parameters
  anim_time += 0.016
  f1 = 2.0 + 0.5 * Math.sin(anim_time * 0.7)
  f2 = 2.0 + 0.5 * Math.sin(anim_time * 0.9)
  f3 = 2.0 + 0.5 * Math.sin(anim_time * 1.1)
  f4 = 2.0 + 0.5 * Math.sin(anim_time * 1.3)
  p1 += 0.002

  # Update UBO via vkMapMemory
  ubo_data = [max_num].pack('L') + [dt, scale, pad0,
    a1, f1, p1, d1, a2, f2, p2, d2,
    a3, f3, p3, d3, a4, f4, p4, d4].pack('f19')
  ptr_buf = "\0"*8
  vk_check(vkMapMemory.call(device, ubo_memory, 0, ubo_size, 0, ptr_buf), "vkMapMemory")
  mapped_ptr = ptr_buf.unpack1('Q')
  Fiddle::Pointer.new(mapped_ptr)[0, ubo_data.bytesize] = ubo_data
  vkUnmapMemory.call(device, ubo_memory)

  # Record command buffer
  cmd = cmd_buffers[idx]
  vk_check(vkResetCommandBuffer.call(cmd, 0), "vkResetCommandBuffer")

  p_begin = vk_command_buffer_begin_ci
  vk_check(vkBeginCommandBuffer.call(cmd, p_begin), "vkBeginCommandBuffer")

  # --- Compute dispatch ---
  vkCmdBindPipeline.call(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, compute_pipeline)
  vkCmdBindDescriptorSets.call(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pipeline_layout, 0, 1, p_desc_set, 0, 0)
  vkCmdDispatch.call(cmd, groups_x, 1, 1)

  # --- Barrier: compute write -> vertex read ---
  vkCmdPipelineBarrier.call(cmd,
    VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
    VK_PIPELINE_STAGE_VERTEX_SHADER_BIT,
    0, 0, 0, 2, p_barriers, 0, 0)

  # --- Render pass ---
  p_rpbi = vk_render_pass_begin_ci(render_pass, framebuffers[idx], cur_w, cur_h, [0.0, 0.0, 0.0, 1.0])
  vkCmdBeginRenderPass.call(cmd, p_rpbi, 0) # VK_SUBPASS_CONTENTS_INLINE
  vkCmdBindPipeline.call(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, graphics_pipeline)
  vkCmdBindDescriptorSets.call(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline_layout, 0, 1, p_desc_set, 0, 0)
  vkCmdDraw.call(cmd, VERTEX_COUNT, 1, 0, 0)
  vkCmdEndRenderPass.call(cmd)

  vk_check(vkEndCommandBuffer.call(cmd), "vkEndCommandBuffer")

  # Submit
  wait_stage = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT].pack('L')
  p_wait_stage = blob(wait_stage)

  submit = [
    VK_STRUCTURE_TYPE_SUBMIT_INFO,
    0,
    1, blob([image_available[cur]].pack('Q')),
    p_wait_stage,
    1, blob([cmd].pack('Q')),
    1, blob([render_finished[cur]].pack('Q'))
  ].pack('L x4 Q L x4 Q Q L x4 Q L x4 Q')
  vk_check(vkQueueSubmit.call(graphics_queue, 1, blob(submit), in_flight[cur]), "vkQueueSubmit")

  # Present
  present = [
    VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
    0,
    1, blob([render_finished[cur]].pack('Q')),
    1, blob([swapchain].pack('Q')),
    blob([idx].pack('L')),
    0
  ].pack('L x4 Q L x4 Q L x4 Q Q Q')
  res = vkQueuePresentKHR.call(present_queue, blob(present))
  raise "vkQueuePresentKHR failed: VkResult=#{res}" unless res == VK_SUCCESS || res == VK_SUBOPTIMAL_KHR

  frame += 1
  Win.Sleep(1)
end

# ============================================================
# Cleanup
# ============================================================
log_msg("STEP: cleanup")
vkDeviceWaitIdle.call(device)

MAX_FRAMES.times do |i|
  vkDestroyFence.call(device, in_flight[i], 0)
  vkDestroySemaphore.call(device, render_finished[i], 0)
  vkDestroySemaphore.call(device, image_available[i], 0)
end

vkDestroyPipeline.call(device, graphics_pipeline, 0)
vkDestroyPipeline.call(device, compute_pipeline, 0)
vkDestroyPipelineLayout.call(device, pipeline_layout, 0)

vkDestroyDescriptorPool.call(device, desc_pool, 0)
vkDestroyDescriptorSetLayout.call(device, desc_set_layout, 0)

vkDestroyBuffer.call(device, ubo_buffer, 0)
vkFreeMemory.call(device, ubo_memory, 0)
vkDestroyBuffer.call(device, col_buffer, 0)
vkFreeMemory.call(device, col_memory, 0)
vkDestroyBuffer.call(device, pos_buffer, 0)
vkFreeMemory.call(device, pos_memory, 0)

vkDestroyShaderModule.call(device, frag_mod, 0)
vkDestroyShaderModule.call(device, vert_mod, 0)
vkDestroyShaderModule.call(device, comp_mod, 0)

framebuffers.each { |fb| vkDestroyFramebuffer.call(device, fb, 0) }
vkDestroyRenderPass.call(device, render_pass, 0)

views.each { |v| vkDestroyImageView.call(device, v, 0) }
vkDestroyCommandPool.call(device, cmd_pool, 0)

vkDestroySwapchainKHR.call(device, swapchain, 0)
vkDestroyDevice.call(device, 0)
vkDestroySurfaceKHR.call(instance, surface, 0)
vkDestroyInstance.call(instance, 0)

log_msg("=== Program End ===")
