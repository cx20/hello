#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
# Vulkan Triangle (Windows, Ruby, Fiddle)
#
# Fixes vs original:
# - Correct 64-bit struct packing/alignment for VkApplicationInfo / VkInstanceCreateInfo (and others)
# - Robust surface + present queue selection (vkGetPhysicalDeviceSurfaceSupportKHR)
# - Robust swapchain format/extent selection (query caps + formats)
# - Full render loop: render pass + pipeline + framebuffers + command buffers + sync
# - Fixed: Removed vkCmdSetViewport/vkCmdSetScissor calls that crash on AMD drivers
#
# Requirements (Windows x64):
# - Ruby 3.x x64
# - Vulkan runtime (vulkan-1.dll)
# - Vulkan SDK (for shaderc_shared.dll OR put shaderc_shared.dll next to this script)
#
# Files in same folder:
# - hello.vert
# - hello.frag

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
  klass = "RubyVulkanTriangle"

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
    0,
    klass,
    title,
    Win::WS_OVERLAPPEDWINDOW,
    Win::CW_USEDEFAULT,
    Win::CW_USEDEFAULT,
    w,
    h,
    nil,
    nil,
    Fiddle::Pointer[hinst],
    nil
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
  VERTEX = 0
  FRAGMENT = 1
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
# Vulkan constants (subset)
# ============================================================
VK_SUCCESS = 0
VK_TRUE = 1
VK_FALSE = 0
VK_SUBOPTIMAL_KHR = 1000001003
VK_ERROR_OUT_OF_DATE_KHR = -1000001004

VK_STRUCTURE_TYPE_APPLICATION_INFO = 0
VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1
VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2
VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3
VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR = 1000009000
VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR = 1000001000
VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15
VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16
VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18
VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19
VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20
VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22
VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23
VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24
VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26
VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28
VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30
VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38
VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37
VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39
VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40
VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42
VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43
VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO = 9
VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8
VK_STRUCTURE_TYPE_SUBMIT_INFO = 4
VK_STRUCTURE_TYPE_PRESENT_INFO_KHR = 1000001002

VK_QUEUE_GRAPHICS_BIT = 0x00000001
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

VK_ATTACHMENT_LOAD_OP_LOAD = 0
VK_ATTACHMENT_LOAD_OP_CLEAR = 1
VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2
VK_ATTACHMENT_STORE_OP_STORE = 0
VK_ATTACHMENT_STORE_OP_DONT_CARE = 1

VK_PIPELINE_BIND_POINT_GRAPHICS = 0
VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3
VK_POLYGON_MODE_FILL = 0
VK_CULL_MODE_NONE = 0
VK_FRONT_FACE_COUNTER_CLOCKWISE = 1
VK_SAMPLE_COUNT_1_BIT = 1

VK_COLOR_COMPONENT_R_BIT = 0x1
VK_COLOR_COMPONENT_G_BIT = 0x2
VK_COLOR_COMPONENT_B_BIT = 0x4
VK_COLOR_COMPONENT_A_BIT = 0x8

VK_SHADER_STAGE_VERTEX_BIT = 0x00000001
VK_SHADER_STAGE_FRAGMENT_BIT = 0x00000010

VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = 0x00000400

VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010
VK_SHARING_MODE_EXCLUSIVE = 0
VK_PRESENT_MODE_FIFO_KHR = 2
VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR = 0x00000001
VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR = 0x00000001

VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001

def vk_check(res, what)
  raise "#{what} failed: VkResult=#{res}" if res != VK_SUCCESS
end

# ============================================================
# Struct builders (x64 packing!)
# ============================================================
def vk_application_info
  p_app = cstr("RubyVulkanTriangle")
  p_eng = cstr("none")
  data = [
    VK_STRUCTURE_TYPE_APPLICATION_INFO,
    0,         # pNext
    p_app,     # pApplicationName
    1,         # applicationVersion
    p_eng,     # pEngineName
    1,         # engineVersion
    vk_make_version(1,4,0)
  ].pack('L x4 Q Q L x4 Q L L')
  blob(data)
end

def vk_instance_create_info(p_app_info)
  ext = [cstr("VK_KHR_surface"), cstr("VK_KHR_win32_surface")]
  ext_arr = blob(ext.pack('Q*'))
  data = [
    VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    0,          # pNext
    0,          # flags
    p_app_info, # pApplicationInfo
    0,          # enabledLayerCount
    0,          # ppEnabledLayerNames
    ext.length, # enabledExtensionCount
    ext_arr     # ppEnabledExtensionNames
  ].pack('L x4 Q L x4 Q L x4 Q L x4 Q')
  blob(data)
end

def vk_win32_surface_ci(hinst, hwnd)
  data = [
    VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    0,    # pNext
    0,    # flags
    hinst,
    hwnd
  ].pack('L x4 Q L x4 Q Q')
  blob(data)
end

def vk_device_queue_ci(qfam, p_prio)
  data = [
    VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    0,
    0,
    qfam,
    1,
    p_prio
  ].pack('L x4 Q L L L x4 Q')
  blob(data)
end

def vk_device_ci(p_queue_ci)
  ext = [cstr("VK_KHR_swapchain")]
  ext_arr = blob(ext.pack('Q*'))
  data = [
    VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    0,
    0,
    1,
    p_queue_ci,
    0,
    0,
    ext.length,
    ext_arr,
    0
  ].pack('L x4 Q L L Q L x4 Q L x4 Q Q')
  blob(data)
end

def vk_swapchain_ci(surface, fmt, colorspace, w, h, min_images, qfam)
  p_qfam = blob([qfam].pack('L'))
  # VkExtent2D: width (bytes 0-3), height (bytes 4-7)
  # On little-endian, low 32 bits go to bytes 0-3, high 32 bits go to bytes 4-7
  extent64 = (u32(h) << 32) | u32(w)  # width in low bits, height in high bits
  # VkSwapchainCreateInfoKHR (104 bytes):
  # sType(4) pad(4) pNext(8) flags(4) pad(4) surface(8)
  # minImageCount(4) imageFormat(4) imageColorSpace(4) imageExtent(8)
  # imageArrayLayers(4) imageUsage(4) imageSharingMode(4) queueFamilyIndexCount(4)
  # pad(4) pQueueFamilyIndices(8)
  # preTransform(4) compositeAlpha(4) presentMode(4) clipped(4) pad(4) oldSwapchain(8)
  data = [
    VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    0,              # pNext
    0,              # flags
    surface,
    min_images,
    fmt,
    colorspace,
    extent64,       # imageExtent (no padding before - VkExtent2D is 4-byte aligned)
    1,              # imageArrayLayers
    VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
    VK_SHARING_MODE_EXCLUSIVE,
    0,              # queueFamilyIndexCount
    0,              # pQueueFamilyIndices (needs padding before - 8-byte aligned pointer)
    VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
    VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
    VK_PRESENT_MODE_FIFO_KHR,
    VK_TRUE,
    0               # oldSwapchain
  ].pack('L x4 Q L x4 Q L L L Q L L L L x4 Q L L L L x4 Q')
  blob(data)
end

def vk_image_view_ci(image, fmt)
  components = [0,0,0,0].pack('L4')
  subrange   = [VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1].pack('L5') + ("\0"*4)
  data = [
    VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    0,
    0,
    image,
    VK_IMAGE_VIEW_TYPE_2D,
    fmt
  ].pack('L x4 Q L x4 Q L L') + components + subrange
  blob(data)
end

def vk_shader_module_ci(code_bytes)
  p_code = blob(code_bytes)
  data = [
    VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    0,
    0,
    code_bytes.bytesize,
    p_code
  ].pack('L x4 Q L x4 Q Q')
  blob(data)
end

def vk_semaphore_ci
  [VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, 0, 0].pack('L x4 Q L')
end

def vk_fence_ci(signaled)
  flags = signaled ? VK_FENCE_CREATE_SIGNALED_BIT : 0
  [VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, 0, flags].pack('L x4 Q L')
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

  subpass_flags = 0
  subpass_bind_pt = VK_PIPELINE_BIND_POINT_GRAPHICS
  input_attach_cnt = 0
  input_p = 0
  color_attach_cnt = 1
  pcolor = p_aref
  presolve = 0
  pdepth = 0
  preserve_cnt = 0
  ppreserve = 0
  
  subpass_data = [subpass_flags, subpass_bind_pt, input_attach_cnt].pack('L3')
  subpass_data += "\0" * 4
  subpass_data += [input_p].pack('Q')
  subpass_data += [color_attach_cnt].pack('L')
  subpass_data += "\0" * 4
  subpass_data += [pcolor].pack('Q')
  subpass_data += [presolve].pack('Q')
  subpass_data += [pdepth].pack('Q')
  subpass_data += [preserve_cnt].pack('L')
  subpass_data += "\0" * 4
  subpass_data += [ppreserve].pack('Q')
  p_subpass = blob(subpass_data)

  rpci_stype = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO
  rpci_pnext = 0
  rpci_flags = 0
  rpci_attach_cnt = 1
  rpci_pattach = p_attach
  rpci_subpass_cnt = 1
  rpci_psubpass = p_subpass
  rpci_dep_cnt = 0
  rpci_pdep = 0
  
  rpci_data = [rpci_stype].pack('L')
  rpci_data += "\0" * 4
  rpci_data += [rpci_pnext].pack('Q')
  rpci_data += [rpci_flags, rpci_attach_cnt].pack('L2')
  rpci_data += [rpci_pattach].pack('Q')
  rpci_data += [rpci_subpass_cnt].pack('L')
  rpci_data += "\0" * 4
  rpci_data += [rpci_psubpass].pack('Q')
  rpci_data += [rpci_dep_cnt].pack('L')
  rpci_data += "\0" * 4
  rpci_data += [rpci_pdep].pack('Q')
  blob(rpci_data)
end

def vk_pipeline_layout_ci
  data = [VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, 0, 0, 0, 0, 0, 0].pack('L x4 Q L L x4 Q L x4 Q')
  blob(data)
end

def vk_framebuffer_ci(render_pass, view, w, h)
  p_attachments = blob([view].pack('Q'))
  # VkFramebufferCreateInfo (64 bytes on x64):
  # sType(4) + pad(4) + pNext(8) + flags(4) + pad(4) + renderPass(8) +
  # attachmentCount(4) + pad(4) + pAttachments(8) + width(4) + height(4) + layers(4) + pad(4)
  data = [
    VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
    0,              # pNext
    0,              # flags
    render_pass,    # renderPass
    1,              # attachmentCount
    p_attachments,  # pAttachments
    w, h, 1         # width, height, layers
  ].pack('L x4 Q L x4 Q L x4 Q L L L x4')
  blob(data)
end

def vk_command_pool_ci(qfam)
  data = [VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, 0, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, qfam].pack('L x4 Q L L')
  blob(data)
end

def vk_command_buffer_alloc_ci(pool, count)
  data = [VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, 0, pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, count].pack('L x4 Q Q L L')
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
  data = [VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, 0, render_pass, fb].pack('L x4 Q Q Q') + render_area + [1].pack('L') + ("\0"*4) + [p_clear].pack('Q')
  blob(data)
end

# ============================================================
# Main
# ============================================================
puts "=== Ruby Vulkan Triangle ==="
log_msg("STEP: shaderc compile")
shaderc = ShaderCompiler.new
dir = Pathname.new(__FILE__).dirname
vert = (dir / "hello.vert").read(encoding: 'utf-8')
frag = (dir / "hello.frag").read(encoding: 'utf-8')
vert_spv = shaderc.compile_glsl(vert, ShaderCompiler::VERTEX, "hello.vert")
frag_spv = shaderc.compile_glsl(frag, ShaderCompiler::FRAGMENT, "hello.frag")
log_msg("shaderc OK: vert #{vert_spv.bytesize} bytes, frag #{frag_spv.bytesize} bytes")

log_msg("STEP: create window")
hwnd, hinst = create_window("Vulkan Triangle (Ruby)", 800, 600)
w, h = get_client_size(hwnd)
log_msg("Window: hwnd=#{hx(hwnd)} hinst=#{hx(hinst)} size=#{w}x#{h}")

# Global functions
vkCreateInstance = vk_fn('vkCreateInstance', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkEnumeratePhysicalDevices = vk_fn('vkEnumeratePhysicalDevices', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkGetPhysicalDeviceQueueFamilyProperties = vk_fn('vkGetPhysicalDeviceQueueFamilyProperties', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
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
vkGetPhysicalDeviceSurfacePresentModesKHR = vk_inst_fn(vkGetInstanceProcAddr, instance, 'vkGetPhysicalDeviceSurfacePresentModesKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])

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

log_msg("STEP: pick queue family (graphics+present)")
qcnt = "\0"*4
vkGetPhysicalDeviceQueueFamilyProperties.call(phys, qcnt, 0)
qcount = qcnt.unpack1('L')
props = "\0"*(qcount*24)
vkGetPhysicalDeviceQueueFamilyProperties.call(phys, qcnt, props)

gfx_q = nil
present_q = nil

qcount.times do |i|
  flags = props[i*24, 4].unpack1('L')
  sup = "\0"*4
  vk_check(vkGetPhysicalDeviceSurfaceSupportKHR.call(phys, i, surface, sup), "vkGetPhysicalDeviceSurfaceSupportKHR")
  present = sup.unpack1('L') != 0
  if (flags & VK_QUEUE_GRAPHICS_BIT) != 0
    gfx_q ||= i
    present_q ||= i if present
  end
  if present && present_q.nil?
    present_q = i
  end
end

raise "No graphics queue" if gfx_q.nil?
raise "No present queue" if present_q.nil?
log_msg("QueueFamily: graphics=#{gfx_q} present=#{present_q}")

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
vkDestroyPipeline = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyPipeline', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateFramebuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateFramebuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyFramebuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyFramebuffer', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateCommandPool = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateCommandPool', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyCommandPool = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyCommandPool', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkAllocateCommandBuffers = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkAllocateCommandBuffers', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkBeginCommandBuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkBeginCommandBuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkEndCommandBuffer = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkEndCommandBuffer', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP])
vkCmdBeginRenderPass = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdBeginRenderPass', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT])
vkCmdEndRenderPass = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdEndRenderPass', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP])
vkCmdBindPipeline = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdBindPipeline', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])
vkCmdDraw = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCmdDraw', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT, Fiddle::TYPE_UINT])

vkCreateSemaphore = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateSemaphore', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroySemaphore = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroySemaphore', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkCreateFence = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkCreateFence', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkDestroyFence = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDestroyFence', Fiddle::TYPE_VOID, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkWaitForFences = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkWaitForFences', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_ULONG_LONG])
vkResetFences = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkResetFences', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP])

vkAcquireNextImageKHR = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkAcquireNextImageKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_ULONG_LONG, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkQueueSubmit = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkQueueSubmit', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_UINT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkQueuePresentKHR = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkQueuePresentKHR', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP])
vkQueueWaitIdle = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkQueueWaitIdle', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP])
vkDeviceWaitIdle = vk_dev_fn(vkGetDeviceProcAddr, device, 'vkDeviceWaitIdle', Fiddle::TYPE_INT, [Fiddle::TYPE_VOIDP])

# Get queues
q_out = "\0"*8
vkGetDeviceQueue.call(device, gfx_q, 0, q_out)
graphics_queue = q_out.unpack1('Q')
vkGetDeviceQueue.call(device, present_q, 0, q_out)
present_queue = q_out.unpack1('Q')
log_msg("Queues: graphics=#{hx(graphics_queue)} present=#{hx(present_queue)}")

# Swapchain selection
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
log_msg("Swapchain: extent=#{cur_w}x#{cur_h} minImages=#{min_images} format=#{chosen_fmt} cs=#{chosen_cs}")

log_msg("STEP: vkCreateSwapchainKHR")
p_swp = vk_swapchain_ci(surface, chosen_fmt, chosen_cs, cur_w, cur_h, min_images, gfx_q)
sw_out = "\0"*8
vk_check(vkCreateSwapchainKHR.call(device, p_swp, 0, sw_out), "vkCreateSwapchainKHR")
swapchain = sw_out.unpack1('Q')
log_msg("Swapchain: #{hx(swapchain)}")

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

# Render pass
log_msg("STEP: render pass")
p_rpci = vk_render_pass_ci(chosen_fmt)
rp_out = "\0"*8
vk_check(vkCreateRenderPass.call(device, p_rpci, 0, rp_out), "vkCreateRenderPass")
render_pass = rp_out.unpack1('Q')
log_msg("Render pass: #{hx(render_pass)}")

# Pipeline layout
p_plci = vk_pipeline_layout_ci
pl_out = "\0"*8
vk_check(vkCreatePipelineLayout.call(device, p_plci, 0, pl_out), "vkCreatePipelineLayout")
pipeline_layout = pl_out.unpack1('Q')

# Shader modules
p_vsm = vk_shader_module_ci(vert_spv)
vsm_out = "\0"*8
vk_check(vkCreateShaderModule.call(device, p_vsm, 0, vsm_out), "vkCreateShaderModule(vert)")
vert_mod = vsm_out.unpack1('Q')

p_fsm = vk_shader_module_ci(frag_spv)
fsm_out = "\0"*8
vk_check(vkCreateShaderModule.call(device, p_fsm, 0, fsm_out), "vkCreateShaderModule(frag)")
frag_mod = fsm_out.unpack1('Q')

# Graphics pipeline (fixed viewport/scissor)
log_msg("STEP: graphics pipeline")

def shader_stage_ci_data(stage, module_handle)
  entry = cstr("main")
  [
    VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    0, 0,
    stage,
    module_handle,
    entry,
    0
  ].pack('L x4 Q L L Q Q Q')
end
stages_data = shader_stage_ci_data(VK_SHADER_STAGE_VERTEX_BIT, vert_mod) +
              shader_stage_ci_data(VK_SHADER_STAGE_FRAGMENT_BIT, frag_mod)
stages = blob(stages_data)

# VkPipelineVertexInputStateCreateInfo (48 bytes)
vi = [VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 +
  [0].pack('Q') +
  [0, 0].pack('L2') +
  [0].pack('Q') +
  [0].pack('L') +
  "\0" * 4 +
  [0].pack('Q')
p_vi = blob(vi)

# VkPipelineInputAssemblyStateCreateInfo (32 bytes)
ia = [VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 +
  [0].pack('Q') +
  [0, VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, VK_FALSE].pack('L3') +
  "\0" * 4
p_ia = blob(ia)

# VkViewport + VkRect2D
viewport = [0.0, 0.0, cur_w.to_f, cur_h.to_f, 0.0, 1.0].pack('f6')
scissor  = [0,0, cur_w, cur_h].pack('l2L2')
p_viewport = blob(viewport)
p_scissor  = blob(scissor)

# VkPipelineViewportStateCreateInfo (48 bytes)
vp = [VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 +
  [0].pack('Q') +
  [0, 1].pack('L2') +
  [p_viewport].pack('Q') +
  [1].pack('L') +
  "\0" * 4 +
  [p_scissor].pack('Q')
p_vp = blob(vp)

# VkPipelineRasterizationStateCreateInfo (64 bytes)
rast = [VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO].pack('L') +
       "\0" * 4 +
       [0].pack('Q') +
       [0, VK_FALSE, VK_FALSE,
  VK_POLYGON_MODE_FILL, VK_CULL_MODE_NONE, VK_FRONT_FACE_COUNTER_CLOCKWISE,
  VK_FALSE].pack('L7') +
       [0.0, 0.0, 0.0, 1.0].pack('f4') +
       "\0" * 4
p_rs = blob(rast)

# VkPipelineMultisampleStateCreateInfo (48 bytes)
ms = [VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 +
  [0].pack('Q') +
  [0, VK_SAMPLE_COUNT_1_BIT, VK_FALSE].pack('L3') +
  [1.0].pack('f') +
  [0].pack('Q') +
  [VK_FALSE, VK_FALSE].pack('L2')
p_ms = blob(ms)

# VkPipelineColorBlendAttachmentState (32 bytes)
cba = [VK_FALSE, 1, 0, 0, 1, 0, 0, (VK_COLOR_COMPONENT_R_BIT|VK_COLOR_COMPONENT_G_BIT|VK_COLOR_COMPONENT_B_BIT|VK_COLOR_COMPONENT_A_BIT)].pack('L8')
p_cba = blob(cba)

# VkPipelineColorBlendStateCreateInfo (56 bytes)
cb = [VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO].pack('L') +
  "\0" * 4 +
  [0].pack('Q') +
  [0, VK_FALSE, 0, 1].pack('L4') +
  [p_cba].pack('Q') +
  [0.0, 0.0, 0.0, 0.0].pack('f4')
p_cb = blob(cb)

# VkGraphicsPipelineCreateInfo (144 bytes) - pDynamicState = 0 (fixed viewport/scissor)
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
pipeline = pipe_out.unpack1('Q')
log_msg("Graphics pipeline: #{hx(pipeline)}")

# Framebuffers
framebuffers = []
views.each do |view|
  p_fbci = vk_framebuffer_ci(render_pass, view, cur_w, cur_h)
  outfb = "\0"*8
  vk_check(vkCreateFramebuffer.call(device, p_fbci, 0, outfb), "vkCreateFramebuffer")
  framebuffers << outfb.unpack1('Q')
end

# Command pool + buffers
log_msg("STEP: command buffers")
p_cpci = vk_command_pool_ci(gfx_q)
cp_out = "\0"*8
vk_check(vkCreateCommandPool.call(device, p_cpci, 0, cp_out), "vkCreateCommandPool")
cmd_pool = cp_out.unpack1('Q')

p_cbai = vk_command_buffer_alloc_ci(cmd_pool, image_count)
cbs = "\0"*(8*image_count)
vk_check(vkAllocateCommandBuffers.call(device, p_cbai, cbs), "vkAllocateCommandBuffers")
cmd_buffers = cbs.unpack('Q*')

# Record command buffers (one per swapchain image)
# NOTE: Using fixed viewport/scissor pipeline, so NO vkCmdSetViewport/vkCmdSetScissor calls
cmd_buffers.each_with_index do |cb, i|
  p_begin = vk_command_buffer_begin_ci
  vk_check(vkBeginCommandBuffer.call(cb, p_begin), "vkBeginCommandBuffer")
  p_rpbi = vk_render_pass_begin_ci(render_pass, framebuffers[i], cur_w, cur_h, [0.1,0.1,0.1,1.0])
  vkCmdBeginRenderPass.call(cb, p_rpbi, 0) # VK_SUBPASS_CONTENTS_INLINE = 0
  vkCmdBindPipeline.call(cb, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline)
  # Fixed viewport/scissor - do NOT call vkCmdSetViewport/vkCmdSetScissor (crashes on AMD)
  vkCmdDraw.call(cb, 3, 1, 0, 0)
  vkCmdEndRenderPass.call(cb)
  vk_check(vkEndCommandBuffer.call(cb), "vkEndCommandBuffer")
end

# Sync objects (double buffering)
log_msg("STEP: sync objects")
MAX_FRAMES = 2
image_available = []
render_finished = []
in_flight = []

sem_ci = [VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO, 0, 0].pack('L x4 Q L')
fence_ci_signaled = [VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, 0, VK_FENCE_CREATE_SIGNALED_BIT].pack('L x4 Q L')

MAX_FRAMES.times do
  s1 = "\0"*8
  s2 = "\0"*8
  f  = "\0"*8
  vk_check(vkCreateSemaphore.call(device, blob(sem_ci), 0, s1), "vkCreateSemaphore")
  vk_check(vkCreateSemaphore.call(device, blob(sem_ci), 0, s2), "vkCreateSemaphore")
  vk_check(vkCreateFence.call(device, blob(fence_ci_signaled), 0, f), "vkCreateFence")
  image_available << s1.unpack1('Q')
  render_finished << s2.unpack1('Q')
  in_flight << f.unpack1('Q')
end

log_msg("STEP: main loop (close window to exit)")
frame = 0
while pump_messages
  cur = frame % MAX_FRAMES
  # wait
  fences = [in_flight[cur]].pack('Q')
  vk_check(vkWaitForFences.call(device, 1, fences, VK_TRUE, 1_000_000_000), "vkWaitForFences")
  vk_check(vkResetFences.call(device, 1, fences), "vkResetFences")

  # acquire
  img_index = "\0"*4
  res = vkAcquireNextImageKHR.call(device, swapchain, 1_000_000_000, image_available[cur], 0, img_index)
  raise "vkAcquireNextImageKHR failed: VkResult=#{res}" unless res == VK_SUCCESS || res == VK_SUBOPTIMAL_KHR
  idx = img_index.unpack1('L')

  # submit
  wait_stage = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT].pack('L')
  p_wait_stage = blob(wait_stage)

  submit = [
    VK_STRUCTURE_TYPE_SUBMIT_INFO,
    0,
    1, blob([image_available[cur]].pack('Q')),
    p_wait_stage,
    1, blob([cmd_buffers[idx]].pack('Q')),
    1, blob([render_finished[cur]].pack('Q'))
  ].pack('L x4 Q L x4 Q Q L x4 Q L x4 Q')
  vk_check(vkQueueSubmit.call(graphics_queue, 1, blob(submit), in_flight[cur]), "vkQueueSubmit")

  # present
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

log_msg("STEP: cleanup")
vkDeviceWaitIdle.call(device)

# Destroy sync
MAX_FRAMES.times do |i|
  vkDestroyFence.call(device, in_flight[i], 0)
  vkDestroySemaphore.call(device, render_finished[i], 0)
  vkDestroySemaphore.call(device, image_available[i], 0)
end

# Destroy pipeline resources
vkDestroyPipeline.call(device, pipeline, 0)
vkDestroyPipelineLayout.call(device, pipeline_layout, 0)
vkDestroyShaderModule.call(device, frag_mod, 0)
vkDestroyShaderModule.call(device, vert_mod, 0)

framebuffers.each { |fb| vkDestroyFramebuffer.call(device, fb, 0) }
vkDestroyRenderPass.call(device, render_pass, 0)

views.each { |v| vkDestroyImageView.call(device, v, 0) }
vkDestroyCommandPool.call(device, cmd_pool, 0)

vkDestroySwapchainKHR.call(device, swapchain, 0)
vkDestroyDevice.call(device, 0)
vkDestroySurfaceKHR.call(instance, surface, 0)
vkDestroyInstance.call(instance, 0)

log_msg("=== Program End ===")
