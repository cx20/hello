//! Harmonograph – Vulkan 1.4 compute + graphics demo (Rust / ash / winit)
//!
//! Architecture (matches the C reference implementation):
//!   1. CPU  – updates HarmonographParams every frame (animation).
//!   2. CPU  – uploads the params to a host-visible UBO.
//!   3. GPU (compute) – reads the UBO; writes pos[] and col[] SSBOs.
//!   4. GPU (barrier) – COMPUTE_SHADER write → VERTEX_SHADER read.
//!   5. GPU (graphics) – draws NUM_POINTS as POINT_LIST (additive blend).
//!
//! Harmonograph equations (evaluated per-point in the compute shader):
//!   x(t) = A1·sin(f1·t + π·p1)·e^(-d1·t) + A2·sin(f2·t + π·p2)·e^(-d2·t)
//!   y(t) = A3·sin(f3·t + π·p3)·e^(-d3·t) + A4·sin(f4·t + π·p4)·e^(-d4·t)
//!
//! Animation: f1–f4 slowly oscillate with sin(), p1 drifts linearly.
//! This matches the C version's drawFrame animation loop exactly.

use ash::ext::debug_utils;
use ash::khr::{surface, swapchain};
use ash::vk;
use raw_window_handle::{HasDisplayHandle, HasWindowHandle};
use std::ffi::{c_char, CStr, CString};
use winit::application::ApplicationHandler;
use winit::dpi::PhysicalSize;
use winit::event::WindowEvent;
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::window::{Window, WindowId};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const WIDTH:  u32 = 800;
const HEIGHT: u32 = 600;
const MAX_FRAMES_IN_FLIGHT: usize = 2;

/// Number of sample points – matches VERTEX_COUNT in the C version.
const NUM_POINTS: u32 = 500_000;

/// Must match local_size_x in the compute shader.
const LOCAL_SIZE_X: u32 = 256;

/// Vulkan 1.4 API version (ash 0.38 has no API_VERSION_1_4 constant).
const API_VERSION_1_4: u32 = vk::make_api_version(0, 1, 4, 0);

#[cfg(debug_assertions)]
const ENABLE_VALIDATION_LAYERS: bool = true;
#[cfg(not(debug_assertions))]
const ENABLE_VALIDATION_LAYERS: bool = false;

const VALIDATION_LAYERS: &[&CStr] = unsafe {
    &[CStr::from_bytes_with_nul_unchecked(b"VK_LAYER_KHRONOS_validation\0")]
};

// ---------------------------------------------------------------------------
// Inline shader sources (verbatim copies of hello.comp / hello.vert / hello.frag)
// ---------------------------------------------------------------------------

const COMPUTE_SHADER_SRC: &str = r#"
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(std140, binding = 2) uniform Params
{
    uint  max_num;
    float dt;
    float scale;
    float pad0;

    float A1; float f1; float p1; float d1;
    float A2; float f2; float p2; float d2;
    float A3; float f3; float p3; float d3;
    float A4; float f4; float p4; float d4;
} u;

vec3 hsv2rgb(float h, float s, float v)
{
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

    float m = v - c;
    return rgb + vec3(m);
}

void main()
{
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= u.max_num) return;

    float t  = float(idx) * u.dt;
    float PI = 3.141592653589793;

    float x = u.A1 * sin(u.f1 * t + PI * u.p1) * exp(-u.d1 * t) +
              u.A2 * sin(u.f2 * t + PI * u.p2) * exp(-u.d2 * t);

    float y = u.A3 * sin(u.f3 * t + PI * u.p3) * exp(-u.d3 * t) +
              u.A4 * sin(u.f4 * t + PI * u.p4) * exp(-u.d4 * t);

    vec2 p = vec2(x, y) * u.scale;
    pos[idx] = vec4(p.x, p.y, 0.0, 1.0);

    float hue = mod((t / 20.0) * 360.0, 360.0);
    vec3 rgb  = hsv2rgb(hue, 1.0, 1.0);
    col[idx]  = vec4(rgb, 1.0);
}
"#;

const VERTEX_SHADER_SRC: &str = r#"
#version 450

layout(std430, binding = 0) buffer Positions { vec4 pos[]; };
layout(std430, binding = 1) buffer Colors    { vec4 col[]; };

layout(location = 0) out vec4 vColor;

void main()
{
    uint idx = uint(gl_VertexIndex);
    gl_Position = pos[idx];
    vColor = col[idx];
}
"#;

const FRAGMENT_SHADER_SRC: &str = r#"
#version 450

layout(location = 0) in  vec4 vColor;
layout(location = 0) out vec4 outColor;

void main()
{
    outColor = vColor;
}
"#;

// ---------------------------------------------------------------------------
// CPU-side UBO struct – must mirror the std140 layout in the compute shader
// ---------------------------------------------------------------------------

/// Harmonograph parameters uploaded to the GPU every frame.
/// Field order and padding must exactly match the GLSL std140 uniform block.
#[repr(C)]
#[derive(Copy, Clone)]
struct HarmonographParams {
    max_num: u32,
    dt:      f32,
    scale:   f32,
    _pad0:   f32,
    // Oscillator A: amplitude, frequency, phase, damping
    a1: f32, f1: f32, p1: f32, d1: f32,
    a2: f32, f2: f32, p2: f32, d2: f32,
    a3: f32, f3: f32, p3: f32, d3: f32,
    a4: f32, f4: f32, p4: f32, d4: f32,
}

impl HarmonographParams {
    /// Initial values matching the C reference implementation.
    fn new() -> Self {
        Self {
            max_num: NUM_POINTS,
            dt:      0.001,           // time step (curve spans ~500 time-units)
            scale:   0.02,            // A=50 * scale=0.02 → peak at ~1.0 NDC
            _pad0:   0.0,
            a1: 50.0, f1: 2.0, p1: 1.0 / 16.0,    d1: 0.02,
            a2: 50.0, f2: 2.0, p2: 3.0 / 2.0,      d2: 0.0315,
            a3: 50.0, f3: 2.0, p3: 13.0 / 15.0,    d3: 0.02,
            a4: 50.0, f4: 2.0, p4: 1.0,             d4: 0.02,
        }
    }

    /// Advance animation by one frame – mirrors drawFrame() in the C version:
    ///   f1–f4 oscillate slowly; p1 drifts by a fixed step each frame.
    fn animate(&mut self, t: f32) {
        self.f1 = 2.0 + 0.5 * (t * 0.7).sin();
        self.f2 = 2.0 + 0.5 * (t * 0.9).sin();
        self.f3 = 2.0 + 0.5 * (t * 1.1).sin();
        self.f4 = 2.0 + 0.5 * (t * 1.3).sin();
        self.p1 += 0.002;
    }
}

// ---------------------------------------------------------------------------
// Shader compilation helper
// ---------------------------------------------------------------------------

fn compile_shader(
    compiler: &shaderc::Compiler,
    source:   &str,
    kind:     shaderc::ShaderKind,
    name:     &str,
) -> Vec<u32> {
    let mut opts = shaderc::CompileOptions::new().unwrap();
    opts.set_target_env(shaderc::TargetEnv::Vulkan, shaderc::EnvVersion::Vulkan1_3 as u32);
    compiler
        .compile_into_spirv(source, kind, name, "main", Some(&opts))
        .unwrap_or_else(|e| panic!("Shader '{}' failed: {}", name, e))
        .as_binary()
        .to_vec()
}

// ---------------------------------------------------------------------------
// Helper types
// ---------------------------------------------------------------------------

struct QueueFamilyIndices {
    /// Queue family that supports both GRAPHICS and COMPUTE.
    graphics_compute: Option<u32>,
    present:          Option<u32>,
}
impl QueueFamilyIndices {
    fn is_complete(&self) -> bool {
        self.graphics_compute.is_some() && self.present.is_some()
    }
}

struct SwapChainSupportDetails {
    capabilities:  vk::SurfaceCapabilitiesKHR,
    formats:       Vec<vk::SurfaceFormatKHR>,
    present_modes: Vec<vk::PresentModeKHR>,
}

// ---------------------------------------------------------------------------
// VulkanApp
// ---------------------------------------------------------------------------

struct VulkanApp {
    window: Window,

    _entry:             ash::Entry,
    instance:           ash::Instance,
    debug_utils_loader: Option<debug_utils::Instance>,
    debug_messenger:    vk::DebugUtilsMessengerEXT,
    surface_loader:     surface::Instance,
    surface:            vk::SurfaceKHR,

    physical_device: vk::PhysicalDevice,
    device:          ash::Device,

    graphics_queue: vk::Queue,
    present_queue:  vk::Queue,

    swapchain_loader:       swapchain::Device,
    swapchain:              vk::SwapchainKHR,
    swapchain_images:       Vec<vk::Image>,
    swapchain_image_format: vk::Format,
    swapchain_extent:       vk::Extent2D,
    swapchain_image_views:  Vec<vk::ImageView>,
    swapchain_framebuffers: Vec<vk::Framebuffer>,

    descriptor_set_layout: vk::DescriptorSetLayout,
    descriptor_pool:       vk::DescriptorPool,
    descriptor_set:        vk::DescriptorSet,

    pos_buffer:           vk::Buffer,
    pos_buffer_memory:    vk::DeviceMemory,
    col_buffer:           vk::Buffer,
    col_buffer_memory:    vk::DeviceMemory,
    params_buffer:        vk::Buffer,
    params_buffer_memory: vk::DeviceMemory,

    compute_pipeline_layout: vk::PipelineLayout,
    compute_pipeline:        vk::Pipeline,

    render_pass:              vk::RenderPass,
    graphics_pipeline_layout: vk::PipelineLayout,
    graphics_pipeline:        vk::Pipeline,

    /// One command buffer per frame-in-flight; reset and re-recorded each frame.
    command_pool:    vk::CommandPool,
    command_buffers: Vec<vk::CommandBuffer>,

    image_available_semaphores: Vec<vk::Semaphore>,
    render_finished_semaphores: Vec<vk::Semaphore>,
    in_flight_fences:           Vec<vk::Fence>,
    images_in_flight:           Vec<vk::Fence>,
    current_frame:              usize,

    framebuffer_resized: bool,

    /// Monotonically increasing animation time; advances 0.016 per frame.
    anim_time: f32,
    /// Live harmonograph parameters; animated every frame, then uploaded to UBO.
    params: HarmonographParams,
}

impl VulkanApp {
    fn new(event_loop: &ActiveEventLoop) -> Self {
        let window = event_loop
            .create_window(
                Window::default_attributes()
                    .with_title("Harmonograph – Vulkan 1.4 Compute")
                    .with_inner_size(PhysicalSize::new(WIDTH, HEIGHT)),
            )
            .unwrap();

        let entry    = unsafe { ash::Entry::load().expect("Failed to load Vulkan") };
        let instance = Self::create_instance(&entry, &window);

        let (debug_utils_loader, debug_messenger) = if ENABLE_VALIDATION_LAYERS {
            Self::setup_debug_messenger(&entry, &instance)
        } else {
            (None, vk::DebugUtilsMessengerEXT::null())
        };

        let surface_loader = surface::Instance::new(&entry, &instance);
        let surface = unsafe {
            ash_window::create_surface(
                &entry, &instance,
                window.display_handle().unwrap().as_raw(),
                window.window_handle().unwrap().as_raw(),
                None,
            ).expect("Failed to create surface")
        };

        let physical_device = Self::pick_physical_device(&instance, &surface_loader, surface);
        let (device, graphics_queue, present_queue) =
            Self::create_logical_device(&instance, physical_device, &surface_loader, surface);

        let swapchain_loader = swapchain::Device::new(&instance, &device);
        let (swapchain, swapchain_images, swapchain_image_format, swapchain_extent) =
            Self::create_swapchain(
                &instance, &surface_loader, surface, physical_device, &swapchain_loader, &window);
        let swapchain_image_views =
            Self::create_image_views(&device, &swapchain_images, swapchain_image_format);

        // Compile all three shaders once at startup.
        let compiler = shaderc::Compiler::new().expect("Failed to create shaderc compiler");
        let compute_spirv = compile_shader(
            &compiler, COMPUTE_SHADER_SRC, shaderc::ShaderKind::Compute,  "hello.comp");
        let vert_spirv = compile_shader(
            &compiler, VERTEX_SHADER_SRC,  shaderc::ShaderKind::Vertex,   "hello.vert");
        let frag_spirv = compile_shader(
            &compiler, FRAGMENT_SHADER_SRC,shaderc::ShaderKind::Fragment,  "hello.frag");

        let (pos_buffer, pos_buffer_memory,
             col_buffer, col_buffer_memory,
             params_buffer, params_buffer_memory) =
            Self::create_buffers(&instance, physical_device, &device);

        let descriptor_set_layout = Self::create_descriptor_set_layout(&device);
        let descriptor_pool       = Self::create_descriptor_pool(&device);
        let descriptor_set        = Self::create_descriptor_set(
            &device, descriptor_pool, descriptor_set_layout,
            pos_buffer, col_buffer, params_buffer,
        );

        let (compute_pipeline_layout, compute_pipeline) =
            Self::create_compute_pipeline(&device, descriptor_set_layout, &compute_spirv);
        let render_pass = Self::create_render_pass(&device, swapchain_image_format);
        let (graphics_pipeline_layout, graphics_pipeline) =
            Self::create_graphics_pipeline(
                &device, descriptor_set_layout, render_pass, swapchain_extent,
                &vert_spirv, &frag_spirv,
            );
        let swapchain_framebuffers = Self::create_framebuffers(
            &device, &swapchain_image_views, render_pass, swapchain_extent);

        let command_pool = Self::create_command_pool(
            &instance, physical_device, &device, &surface_loader, surface);
        // Allocate MAX_FRAMES_IN_FLIGHT command buffers; recording happens per-frame.
        let command_buffers = Self::allocate_command_buffers(&device, command_pool);

        let (image_available_semaphores, render_finished_semaphores, in_flight_fences) =
            Self::create_sync_objects(&device);
        let images_in_flight = vec![vk::Fence::null(); swapchain_images.len()];

        let params = HarmonographParams::new();
        // Write initial params to the UBO before the first frame.
        Self::upload_params(&device, params_buffer_memory, &params);

        Self {
            window,
            _entry: entry,
            instance,
            debug_utils_loader,
            debug_messenger,
            surface_loader,
            surface,
            physical_device,
            device,
            graphics_queue,
            present_queue,
            swapchain_loader,
            swapchain,
            swapchain_images,
            swapchain_image_format,
            swapchain_extent,
            swapchain_image_views,
            swapchain_framebuffers,
            descriptor_set_layout,
            descriptor_pool,
            descriptor_set,
            pos_buffer,
            pos_buffer_memory,
            col_buffer,
            col_buffer_memory,
            params_buffer,
            params_buffer_memory,
            compute_pipeline_layout,
            compute_pipeline,
            render_pass,
            graphics_pipeline_layout,
            graphics_pipeline,
            command_pool,
            command_buffers,
            image_available_semaphores,
            render_finished_semaphores,
            in_flight_fences,
            images_in_flight,
            current_frame: 0,
            framebuffer_resized: false,
            anim_time: 0.0,
            params,
        }
    }

    // -----------------------------------------------------------------------
    // Instance creation
    // -----------------------------------------------------------------------

    fn create_instance(entry: &ash::Entry, window: &Window) -> ash::Instance {
        if ENABLE_VALIDATION_LAYERS && !Self::check_validation_layer_support(entry) {
            panic!("Validation layers requested but not available!");
        }
        let app_name    = CString::new("Harmonograph Vulkan").unwrap();
        let engine_name = CString::new("No Engine").unwrap();
        let app_info = vk::ApplicationInfo::default()
            .application_name(&app_name)
            .application_version(vk::make_api_version(0, 1, 0, 0))
            .engine_name(&engine_name)
            .engine_version(vk::make_api_version(0, 1, 0, 0))
            .api_version(API_VERSION_1_4);

        let mut exts = ash_window::enumerate_required_extensions(
            window.display_handle().unwrap().as_raw()).unwrap().to_vec();
        if ENABLE_VALIDATION_LAYERS { exts.push(debug_utils::NAME.as_ptr()); }

        let layers: Vec<*const c_char> = if ENABLE_VALIDATION_LAYERS {
            VALIDATION_LAYERS.iter().map(|l| l.as_ptr()).collect()
        } else { vec![] };

        let mut ci = vk::InstanceCreateInfo::default()
            .application_info(&app_info)
            .enabled_extension_names(&exts)
            .enabled_layer_names(&layers);
        let mut dbg = Self::populate_debug_messenger_create_info();
        if ENABLE_VALIDATION_LAYERS { ci = ci.push_next(&mut dbg); }

        unsafe { entry.create_instance(&ci, None).unwrap() }
    }

    fn check_validation_layer_support(entry: &ash::Entry) -> bool {
        let available = unsafe { entry.enumerate_instance_layer_properties().unwrap() };
        VALIDATION_LAYERS.iter().all(|wanted| {
            available.iter().any(|layer| {
                let name = unsafe { CStr::from_ptr(layer.layer_name.as_ptr()) };
                name == *wanted
            })
        })
    }

    fn populate_debug_messenger_create_info() -> vk::DebugUtilsMessengerCreateInfoEXT<'static> {
        vk::DebugUtilsMessengerCreateInfoEXT::default()
            .message_severity(
                vk::DebugUtilsMessageSeverityFlagsEXT::WARNING
                    | vk::DebugUtilsMessageSeverityFlagsEXT::ERROR)
            .message_type(
                vk::DebugUtilsMessageTypeFlagsEXT::GENERAL
                    | vk::DebugUtilsMessageTypeFlagsEXT::VALIDATION
                    | vk::DebugUtilsMessageTypeFlagsEXT::PERFORMANCE)
            .pfn_user_callback(Some(vulkan_debug_callback))
    }

    fn setup_debug_messenger(
        entry: &ash::Entry, instance: &ash::Instance,
    ) -> (Option<debug_utils::Instance>, vk::DebugUtilsMessengerEXT) {
        let loader = debug_utils::Instance::new(entry, instance);
        let info   = Self::populate_debug_messenger_create_info();
        let handle = unsafe { loader.create_debug_utils_messenger(&info, None).unwrap() };
        (Some(loader), handle)
    }

    // -----------------------------------------------------------------------
    // Physical / logical device
    // -----------------------------------------------------------------------

    fn pick_physical_device(
        instance: &ash::Instance, sl: &surface::Instance, surface: vk::SurfaceKHR,
    ) -> vk::PhysicalDevice {
        unsafe { instance.enumerate_physical_devices().unwrap() }
            .into_iter()
            .find(|&dev| Self::is_device_suitable(instance, dev, sl, surface))
            .expect("No suitable GPU (needs graphics+compute+swapchain)")
    }

    fn is_device_suitable(
        instance: &ash::Instance, device: vk::PhysicalDevice,
        sl: &surface::Instance, surface: vk::SurfaceKHR,
    ) -> bool {
        if !Self::find_queue_families(instance, device, sl, surface).is_complete() {
            return false;
        }
        let exts_ok = unsafe { instance.enumerate_device_extension_properties(device).unwrap() }
            .iter()
            .any(|e| {
                let name = unsafe { CStr::from_ptr(e.extension_name.as_ptr()) };
                name == swapchain::NAME
            });
        if !exts_ok { return false; }
        let details = Self::query_swapchain_support(device, sl, surface);
        !details.formats.is_empty() && !details.present_modes.is_empty()
    }

    fn find_queue_families(
        instance: &ash::Instance, device: vk::PhysicalDevice,
        sl: &surface::Instance, surface: vk::SurfaceKHR,
    ) -> QueueFamilyIndices {
        let families = unsafe { instance.get_physical_device_queue_family_properties(device) };
        let mut idx = QueueFamilyIndices { graphics_compute: None, present: None };
        for (i, fam) in families.iter().enumerate() {
            let i = i as u32;
            if fam.queue_flags.contains(vk::QueueFlags::GRAPHICS | vk::QueueFlags::COMPUTE) {
                idx.graphics_compute = Some(i);
            }
            let present_ok = unsafe {
                sl.get_physical_device_surface_support(device, i, surface).unwrap()
            };
            if present_ok { idx.present = Some(i); }
            if idx.is_complete() { break; }
        }
        idx
    }

    fn create_logical_device(
        instance: &ash::Instance, physical_device: vk::PhysicalDevice,
        sl: &surface::Instance, surface: vk::SurfaceKHR,
    ) -> (ash::Device, vk::Queue, vk::Queue) {
        let idx = Self::find_queue_families(instance, physical_device, sl, surface);
        let mut unique = vec![idx.graphics_compute.unwrap(), idx.present.unwrap()];
        unique.sort_unstable(); unique.dedup();

        let priority = 1.0f32;
        let queue_infos: Vec<_> = unique.iter().map(|&fam|
            vk::DeviceQueueCreateInfo::default()
                .queue_family_index(fam)
                .queue_priorities(std::slice::from_ref(&priority))
        ).collect();

        let ext_names    = [swapchain::NAME.as_ptr()];
        let device_feats = vk::PhysicalDeviceFeatures::default();

        #[allow(deprecated)]
        let layers: Vec<*const c_char> = if ENABLE_VALIDATION_LAYERS {
            VALIDATION_LAYERS.iter().map(|l| l.as_ptr()).collect()
        } else { vec![] };

        #[allow(deprecated)]
        let ci = vk::DeviceCreateInfo::default()
            .queue_create_infos(&queue_infos)
            .enabled_features(&device_feats)
            .enabled_extension_names(&ext_names)
            .enabled_layer_names(&layers);

        let device = unsafe { instance.create_device(physical_device, &ci, None).unwrap() };
        let gfx_q  = unsafe { device.get_device_queue(idx.graphics_compute.unwrap(), 0) };
        let prs_q  = unsafe { device.get_device_queue(idx.present.unwrap(), 0) };
        (device, gfx_q, prs_q)
    }

    // -----------------------------------------------------------------------
    // Swapchain
    // -----------------------------------------------------------------------

    fn query_swapchain_support(
        device: vk::PhysicalDevice, sl: &surface::Instance, surface: vk::SurfaceKHR,
    ) -> SwapChainSupportDetails {
        unsafe {
            SwapChainSupportDetails {
                capabilities:  sl.get_physical_device_surface_capabilities(device, surface).unwrap(),
                formats:       sl.get_physical_device_surface_formats(device, surface).unwrap(),
                present_modes: sl.get_physical_device_surface_present_modes(device, surface).unwrap(),
            }
        }
    }

    fn create_swapchain(
        instance: &ash::Instance, sl: &surface::Instance,
        surface: vk::SurfaceKHR, physical_device: vk::PhysicalDevice,
        sc_loader: &swapchain::Device, window: &Window,
    ) -> (vk::SwapchainKHR, Vec<vk::Image>, vk::Format, vk::Extent2D) {
        let details = Self::query_swapchain_support(physical_device, sl, surface);

        let fmt = details.formats.iter()
            .find(|f| f.format == vk::Format::B8G8R8A8_SRGB
                   && f.color_space == vk::ColorSpaceKHR::SRGB_NONLINEAR)
            .cloned().unwrap_or(details.formats[0]);

        let present_mode = details.present_modes.iter()
            .find(|&&m| m == vk::PresentModeKHR::MAILBOX)
            .cloned().unwrap_or(vk::PresentModeKHR::FIFO);

        let extent = if details.capabilities.current_extent.width != u32::MAX {
            details.capabilities.current_extent
        } else {
            let sz = window.inner_size();
            vk::Extent2D {
                width:  sz.width .clamp(details.capabilities.min_image_extent.width,
                                        details.capabilities.max_image_extent.width),
                height: sz.height.clamp(details.capabilities.min_image_extent.height,
                                        details.capabilities.max_image_extent.height),
            }
        };

        let mut image_count = details.capabilities.min_image_count + 1;
        if details.capabilities.max_image_count > 0
            && image_count > details.capabilities.max_image_count
        {
            image_count = details.capabilities.max_image_count;
        }

        let idx = Self::find_queue_families(instance, physical_device, sl, surface);
        let qfi = [idx.graphics_compute.unwrap(), idx.present.unwrap()];
        let (sharing, qfi_count, qfi_ptr) = if idx.graphics_compute != idx.present {
            (vk::SharingMode::CONCURRENT, 2, qfi.as_ptr())
        } else {
            (vk::SharingMode::EXCLUSIVE, 0, std::ptr::null())
        };

        let ci = vk::SwapchainCreateInfoKHR {
            s_type:                   vk::StructureType::SWAPCHAIN_CREATE_INFO_KHR,
            surface,
            min_image_count:          image_count,
            image_format:             fmt.format,
            image_color_space:        fmt.color_space,
            image_extent:             extent,
            image_array_layers:       1,
            image_usage:              vk::ImageUsageFlags::COLOR_ATTACHMENT,
            image_sharing_mode:       sharing,
            queue_family_index_count: qfi_count,
            p_queue_family_indices:   qfi_ptr,
            pre_transform:            details.capabilities.current_transform,
            composite_alpha:          vk::CompositeAlphaFlagsKHR::OPAQUE,
            present_mode,
            clipped:                  vk::TRUE,
            old_swapchain:            vk::SwapchainKHR::null(),
            ..Default::default()
        };
        let sc     = unsafe { sc_loader.create_swapchain(&ci, None).unwrap() };
        let images = unsafe { sc_loader.get_swapchain_images(sc).unwrap() };
        (sc, images, fmt.format, extent)
    }

    fn create_image_views(
        device: &ash::Device, images: &[vk::Image], format: vk::Format,
    ) -> Vec<vk::ImageView> {
        images.iter().map(|&img| {
            let ci = vk::ImageViewCreateInfo::default()
                .image(img)
                .view_type(vk::ImageViewType::TYPE_2D)
                .format(format)
                .subresource_range(vk::ImageSubresourceRange {
                    aspect_mask:      vk::ImageAspectFlags::COLOR,
                    base_mip_level:   0, level_count:      1,
                    base_array_layer: 0, layer_count:      1,
                });
            unsafe { device.create_image_view(&ci, None).unwrap() }
        }).collect()
    }

    // -----------------------------------------------------------------------
    // GPU buffers
    // -----------------------------------------------------------------------

    fn find_memory_type(
        instance: &ash::Instance, physical_device: vk::PhysicalDevice,
        type_filter: u32, props: vk::MemoryPropertyFlags,
    ) -> u32 {
        let mem_props = unsafe { instance.get_physical_device_memory_properties(physical_device) };
        (0..mem_props.memory_type_count)
            .find(|&i| {
                (type_filter & (1 << i)) != 0
                    && mem_props.memory_types[i as usize].property_flags.contains(props)
            })
            .expect("No suitable memory type")
    }

    fn alloc_buffer(
        instance: &ash::Instance, physical_device: vk::PhysicalDevice,
        device: &ash::Device, size: vk::DeviceSize,
        usage: vk::BufferUsageFlags, mem_props: vk::MemoryPropertyFlags,
    ) -> (vk::Buffer, vk::DeviceMemory) {
        let buf = unsafe {
            device.create_buffer(
                &vk::BufferCreateInfo::default()
                    .size(size).usage(usage)
                    .sharing_mode(vk::SharingMode::EXCLUSIVE),
                None).unwrap()
        };
        let reqs = unsafe { device.get_buffer_memory_requirements(buf) };
        let mt   = Self::find_memory_type(instance, physical_device, reqs.memory_type_bits, mem_props);
        let mem  = unsafe {
            device.allocate_memory(
                &vk::MemoryAllocateInfo::default()
                    .allocation_size(reqs.size)
                    .memory_type_index(mt),
                None).unwrap()
        };
        unsafe { device.bind_buffer_memory(buf, mem, 0).unwrap() };
        (buf, mem)
    }

    fn create_buffers(
        instance: &ash::Instance, physical_device: vk::PhysicalDevice, device: &ash::Device,
    ) -> (vk::Buffer, vk::DeviceMemory, vk::Buffer, vk::DeviceMemory,
          vk::Buffer, vk::DeviceMemory)
    {
        let ssbo_bytes = (NUM_POINTS as vk::DeviceSize) * 16; // vec4 = 16 bytes each

        // SSBOs written by compute and read by the vertex shader.
        let ssbo_usage = vk::BufferUsageFlags::STORAGE_BUFFER;
        let ssbo_flags = vk::MemoryPropertyFlags::DEVICE_LOCAL
                       | vk::MemoryPropertyFlags::HOST_VISIBLE;
        let (pos_buf, pos_mem) = Self::alloc_buffer(
            instance, physical_device, device, ssbo_bytes, ssbo_usage, ssbo_flags);
        let (col_buf, col_mem) = Self::alloc_buffer(
            instance, physical_device, device, ssbo_bytes, ssbo_usage, ssbo_flags);

        // UBO: host-visible + coherent for CPU updates every frame.
        let ubo_bytes = std::mem::size_of::<HarmonographParams>() as vk::DeviceSize;
        let (prm_buf, prm_mem) = Self::alloc_buffer(
            instance, physical_device, device, ubo_bytes,
            vk::BufferUsageFlags::UNIFORM_BUFFER,
            vk::MemoryPropertyFlags::HOST_VISIBLE | vk::MemoryPropertyFlags::HOST_COHERENT,
        );

        (pos_buf, pos_mem, col_buf, col_mem, prm_buf, prm_mem)
    }

    /// Map, write, and unmap the host-coherent UBO.
    /// HOST_COHERENT means no explicit flush is needed.
    fn upload_params(
        device: &ash::Device, memory: vk::DeviceMemory, params: &HarmonographParams,
    ) {
        let size = std::mem::size_of::<HarmonographParams>() as vk::DeviceSize;
        unsafe {
            let ptr = device
                .map_memory(memory, 0, size, vk::MemoryMapFlags::empty())
                .unwrap() as *mut HarmonographParams;
            ptr.write(*params);
            device.unmap_memory(memory);
        }
    }

    // -----------------------------------------------------------------------
    // Descriptors
    // -----------------------------------------------------------------------

    /// Layout shared by compute (all bindings) and graphics (bindings 0 & 1 only).
    ///   binding 0 – STORAGE_BUFFER pos[]   (COMPUTE + VERTEX)
    ///   binding 1 – STORAGE_BUFFER col[]   (COMPUTE + VERTEX)
    ///   binding 2 – UNIFORM_BUFFER params  (COMPUTE)
    fn create_descriptor_set_layout(device: &ash::Device) -> vk::DescriptorSetLayout {
        let cv = vk::ShaderStageFlags::COMPUTE | vk::ShaderStageFlags::VERTEX;
        let bindings = [
            vk::DescriptorSetLayoutBinding::default()
                .binding(0).descriptor_type(vk::DescriptorType::STORAGE_BUFFER)
                .descriptor_count(1).stage_flags(cv),
            vk::DescriptorSetLayoutBinding::default()
                .binding(1).descriptor_type(vk::DescriptorType::STORAGE_BUFFER)
                .descriptor_count(1).stage_flags(cv),
            vk::DescriptorSetLayoutBinding::default()
                .binding(2).descriptor_type(vk::DescriptorType::UNIFORM_BUFFER)
                .descriptor_count(1).stage_flags(vk::ShaderStageFlags::COMPUTE),
        ];
        unsafe {
            device.create_descriptor_set_layout(
                &vk::DescriptorSetLayoutCreateInfo::default().bindings(&bindings), None).unwrap()
        }
    }

    fn create_descriptor_pool(device: &ash::Device) -> vk::DescriptorPool {
        let pool_sizes = [
            vk::DescriptorPoolSize { ty: vk::DescriptorType::STORAGE_BUFFER, descriptor_count: 2 },
            vk::DescriptorPoolSize { ty: vk::DescriptorType::UNIFORM_BUFFER, descriptor_count: 1 },
        ];
        unsafe {
            device.create_descriptor_pool(
                &vk::DescriptorPoolCreateInfo::default()
                    .pool_sizes(&pool_sizes).max_sets(1),
                None).unwrap()
        }
    }

    fn create_descriptor_set(
        device: &ash::Device, pool: vk::DescriptorPool, layout: vk::DescriptorSetLayout,
        pos_buf: vk::Buffer, col_buf: vk::Buffer, prm_buf: vk::Buffer,
    ) -> vk::DescriptorSet {
        let set = unsafe {
            device.allocate_descriptor_sets(
                &vk::DescriptorSetAllocateInfo::default()
                    .descriptor_pool(pool)
                    .set_layouts(std::slice::from_ref(&layout)),
            ).unwrap()[0]
        };
        let ssbo_b = (NUM_POINTS as vk::DeviceSize) * 16;
        let ubo_b  = std::mem::size_of::<HarmonographParams>() as vk::DeviceSize;
        let pos_bi = [vk::DescriptorBufferInfo::default().buffer(pos_buf).offset(0).range(ssbo_b)];
        let col_bi = [vk::DescriptorBufferInfo::default().buffer(col_buf).offset(0).range(ssbo_b)];
        let prm_bi = [vk::DescriptorBufferInfo::default().buffer(prm_buf).offset(0).range(ubo_b)];
        let writes = [
            vk::WriteDescriptorSet::default().dst_set(set).dst_binding(0)
                .descriptor_type(vk::DescriptorType::STORAGE_BUFFER).buffer_info(&pos_bi),
            vk::WriteDescriptorSet::default().dst_set(set).dst_binding(1)
                .descriptor_type(vk::DescriptorType::STORAGE_BUFFER).buffer_info(&col_bi),
            vk::WriteDescriptorSet::default().dst_set(set).dst_binding(2)
                .descriptor_type(vk::DescriptorType::UNIFORM_BUFFER).buffer_info(&prm_bi),
        ];
        unsafe { device.update_descriptor_sets(&writes, &[]) };
        set
    }

    // -----------------------------------------------------------------------
    // Pipelines
    // -----------------------------------------------------------------------

    fn create_compute_pipeline(
        device: &ash::Device, layout: vk::DescriptorSetLayout, spirv: &[u32],
    ) -> (vk::PipelineLayout, vk::Pipeline) {
        let module = Self::create_shader_module(device, spirv);
        let entry  = CString::new("main").unwrap();
        let stage  = vk::PipelineShaderStageCreateInfo::default()
            .stage(vk::ShaderStageFlags::COMPUTE).module(module).name(&entry);
        let layouts = [layout];
        let pl = unsafe {
            device.create_pipeline_layout(
                &vk::PipelineLayoutCreateInfo::default().set_layouts(&layouts), None).unwrap()
        };
        let pipeline = unsafe {
            device.create_compute_pipelines(
                vk::PipelineCache::null(),
                std::slice::from_ref(&vk::ComputePipelineCreateInfo::default()
                    .stage(stage).layout(pl)),
                None).unwrap()[0]
        };
        unsafe { device.destroy_shader_module(module, None) };
        (pl, pipeline)
    }

    fn create_render_pass(device: &ash::Device, format: vk::Format) -> vk::RenderPass {
        let att = vk::AttachmentDescription::default()
            .format(format)
            .samples(vk::SampleCountFlags::TYPE_1)
            .load_op(vk::AttachmentLoadOp::CLEAR)
            .store_op(vk::AttachmentStoreOp::STORE)
            .stencil_load_op(vk::AttachmentLoadOp::DONT_CARE)
            .stencil_store_op(vk::AttachmentStoreOp::DONT_CARE)
            .initial_layout(vk::ImageLayout::UNDEFINED)
            .final_layout(vk::ImageLayout::PRESENT_SRC_KHR);
        let att_ref = vk::AttachmentReference {
            attachment: 0, layout: vk::ImageLayout::COLOR_ATTACHMENT_OPTIMAL,
        };
        let subpass = vk::SubpassDescription::default()
            .pipeline_bind_point(vk::PipelineBindPoint::GRAPHICS)
            .color_attachments(std::slice::from_ref(&att_ref));
        let dep = vk::SubpassDependency::default()
            .src_subpass(vk::SUBPASS_EXTERNAL).dst_subpass(0)
            .src_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .src_access_mask(vk::AccessFlags::empty())
            .dst_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .dst_access_mask(vk::AccessFlags::COLOR_ATTACHMENT_WRITE);
        unsafe {
            device.create_render_pass(
                &vk::RenderPassCreateInfo::default()
                    .attachments(std::slice::from_ref(&att))
                    .subpasses(std::slice::from_ref(&subpass))
                    .dependencies(std::slice::from_ref(&dep)),
                None).unwrap()
        }
    }

    fn create_graphics_pipeline(
        device: &ash::Device, layout: vk::DescriptorSetLayout,
        render_pass: vk::RenderPass, extent: vk::Extent2D,
        vert_spirv: &[u32], frag_spirv: &[u32],
    ) -> (vk::PipelineLayout, vk::Pipeline) {
        let vert_mod = Self::create_shader_module(device, vert_spirv);
        let frag_mod = Self::create_shader_module(device, frag_spirv);
        let entry    = CString::new("main").unwrap();
        let stages = [
            vk::PipelineShaderStageCreateInfo::default()
                .stage(vk::ShaderStageFlags::VERTEX)  .module(vert_mod).name(&entry),
            vk::PipelineShaderStageCreateInfo::default()
                .stage(vk::ShaderStageFlags::FRAGMENT).module(frag_mod).name(&entry),
        ];

        // Vertex input: empty – vertex shader reads SSBOs via gl_VertexIndex.
        let vi = vk::PipelineVertexInputStateCreateInfo::default();

        // Render the harmonograph curve as individual pixels.
        let ia = vk::PipelineInputAssemblyStateCreateInfo::default()
            .topology(vk::PrimitiveTopology::POINT_LIST)
            .primitive_restart_enable(false);

        let viewport = vk::Viewport {
            x: 0.0, y: 0.0,
            width: extent.width as f32, height: extent.height as f32,
            min_depth: 0.0, max_depth: 1.0,
        };
        let scissor  = vk::Rect2D { offset: vk::Offset2D { x: 0, y: 0 }, extent };
        let vp_state = vk::PipelineViewportStateCreateInfo::default()
            .viewports(std::slice::from_ref(&viewport))
            .scissors(std::slice::from_ref(&scissor));

        let rasterizer = vk::PipelineRasterizationStateCreateInfo::default()
            .depth_clamp_enable(false).rasterizer_discard_enable(false)
            .polygon_mode(vk::PolygonMode::FILL).line_width(1.0)
            .cull_mode(vk::CullModeFlags::NONE)
            .front_face(vk::FrontFace::CLOCKWISE).depth_bias_enable(false);

        let ms = vk::PipelineMultisampleStateCreateInfo::default()
            .sample_shading_enable(false)
            .rasterization_samples(vk::SampleCountFlags::TYPE_1);

        // Additive blending: overlapping points accumulate brightness.
        let blend_att = vk::PipelineColorBlendAttachmentState {
            blend_enable:           vk::TRUE,
            src_color_blend_factor: vk::BlendFactor::ONE,
            dst_color_blend_factor: vk::BlendFactor::ONE,
            color_blend_op:         vk::BlendOp::ADD,
            src_alpha_blend_factor: vk::BlendFactor::ONE,
            dst_alpha_blend_factor: vk::BlendFactor::ONE,
            alpha_blend_op:         vk::BlendOp::ADD,
            color_write_mask:       vk::ColorComponentFlags::RGBA,
        };
        let cb = vk::PipelineColorBlendStateCreateInfo::default()
            .logic_op_enable(false)
            .attachments(std::slice::from_ref(&blend_att));

        let layouts = [layout];
        let pl = unsafe {
            device.create_pipeline_layout(
                &vk::PipelineLayoutCreateInfo::default().set_layouts(&layouts), None).unwrap()
        };
        let pi = vk::GraphicsPipelineCreateInfo::default()
            .stages(&stages).vertex_input_state(&vi).input_assembly_state(&ia)
            .viewport_state(&vp_state).rasterization_state(&rasterizer)
            .multisample_state(&ms).color_blend_state(&cb)
            .layout(pl).render_pass(render_pass).subpass(0);
        let pipeline = unsafe {
            device.create_graphics_pipelines(
                vk::PipelineCache::null(), std::slice::from_ref(&pi), None).unwrap()[0]
        };
        unsafe {
            device.destroy_shader_module(vert_mod, None);
            device.destroy_shader_module(frag_mod, None);
        }
        (pl, pipeline)
    }

    fn create_shader_module(device: &ash::Device, code: &[u32]) -> vk::ShaderModule {
        unsafe {
            device.create_shader_module(
                &vk::ShaderModuleCreateInfo::default().code(code), None).unwrap()
        }
    }

    // -----------------------------------------------------------------------
    // Framebuffers
    // -----------------------------------------------------------------------

    fn create_framebuffers(
        device: &ash::Device, views: &[vk::ImageView],
        render_pass: vk::RenderPass, extent: vk::Extent2D,
    ) -> Vec<vk::Framebuffer> {
        views.iter().map(|&view| unsafe {
            device.create_framebuffer(
                &vk::FramebufferCreateInfo::default()
                    .render_pass(render_pass)
                    .attachments(std::slice::from_ref(&view))
                    .width(extent.width).height(extent.height).layers(1),
                None).unwrap()
        }).collect()
    }

    // -----------------------------------------------------------------------
    // Command pool and per-frame recording
    // -----------------------------------------------------------------------

    fn create_command_pool(
        instance: &ash::Instance, physical_device: vk::PhysicalDevice,
        device: &ash::Device, sl: &surface::Instance, surface: vk::SurfaceKHR,
    ) -> vk::CommandPool {
        let idx = Self::find_queue_families(instance, physical_device, sl, surface);
        unsafe {
            device.create_command_pool(
                &vk::CommandPoolCreateInfo::default()
                    .queue_family_index(idx.graphics_compute.unwrap())
                    // RESET_COMMAND_BUFFER: individual buffers can be reset per-frame.
                    .flags(vk::CommandPoolCreateFlags::RESET_COMMAND_BUFFER),
                None).unwrap()
        }
    }

    /// Allocate MAX_FRAMES_IN_FLIGHT command buffers.
    /// The actual recording is deferred to record_frame_commands().
    fn allocate_command_buffers(
        device: &ash::Device, pool: vk::CommandPool,
    ) -> Vec<vk::CommandBuffer> {
        unsafe {
            device.allocate_command_buffers(
                &vk::CommandBufferAllocateInfo::default()
                    .command_pool(pool)
                    .level(vk::CommandBufferLevel::PRIMARY)
                    .command_buffer_count(MAX_FRAMES_IN_FLIGHT as u32),
            ).unwrap()
        }
    }

    /// Reset and re-record the command buffer for the current frame.
    /// Called every frame from draw_frame(), after the UBO has been updated.
    ///
    /// Recording order (mirrors recordCmd() in the C version):
    ///   1. Dispatch compute shader → fills pos[]/col[] SSBOs.
    ///   2. Memory barrier: compute write → vertex read.
    ///   3. Render pass → draw NUM_POINTS as POINT_LIST.
    fn record_frame_commands(&self, cmd: vk::CommandBuffer, image_index: u32) {
        let ssbo_bytes = (NUM_POINTS as vk::DeviceSize) * 16;
        unsafe {
            // Reset this individual command buffer (pool has RESET_COMMAND_BUFFER).
            self.device
                .reset_command_buffer(cmd, vk::CommandBufferResetFlags::empty())
                .unwrap();
            self.device
                .begin_command_buffer(cmd, &vk::CommandBufferBeginInfo::default())
                .unwrap();

            // ── 1. Compute dispatch ──────────────────────────────────────
            self.device.cmd_bind_pipeline(
                cmd, vk::PipelineBindPoint::COMPUTE, self.compute_pipeline);
            self.device.cmd_bind_descriptor_sets(
                cmd, vk::PipelineBindPoint::COMPUTE,
                self.compute_pipeline_layout, 0, &[self.descriptor_set], &[]);
            let groups = (NUM_POINTS + LOCAL_SIZE_X - 1) / LOCAL_SIZE_X;
            self.device.cmd_dispatch(cmd, groups, 1, 1);

            // ── 2. Memory barrier: compute writes → vertex reads ─────────
            let barriers = [
                vk::BufferMemoryBarrier::default()
                    .src_access_mask(vk::AccessFlags::SHADER_WRITE)
                    .dst_access_mask(vk::AccessFlags::SHADER_READ)
                    .src_queue_family_index(vk::QUEUE_FAMILY_IGNORED)
                    .dst_queue_family_index(vk::QUEUE_FAMILY_IGNORED)
                    .buffer(self.pos_buffer).offset(0).size(ssbo_bytes),
                vk::BufferMemoryBarrier::default()
                    .src_access_mask(vk::AccessFlags::SHADER_WRITE)
                    .dst_access_mask(vk::AccessFlags::SHADER_READ)
                    .src_queue_family_index(vk::QUEUE_FAMILY_IGNORED)
                    .dst_queue_family_index(vk::QUEUE_FAMILY_IGNORED)
                    .buffer(self.col_buffer).offset(0).size(ssbo_bytes),
            ];
            self.device.cmd_pipeline_barrier(
                cmd,
                vk::PipelineStageFlags::COMPUTE_SHADER,  // after compute writes
                vk::PipelineStageFlags::VERTEX_SHADER,    // before vertex reads
                vk::DependencyFlags::empty(),
                &[], &barriers, &[],
            );

            // ── 3. Render pass: draw point cloud ─────────────────────────
            let clear = vk::ClearValue {
                color: vk::ClearColorValue { float32: [0.0, 0.0, 0.0, 1.0] },
            };
            let rp_info = vk::RenderPassBeginInfo::default()
                .render_pass(self.render_pass)
                .framebuffer(self.swapchain_framebuffers[image_index as usize])
                .render_area(vk::Rect2D {
                    offset: vk::Offset2D { x: 0, y: 0 },
                    extent: self.swapchain_extent,
                })
                .clear_values(std::slice::from_ref(&clear));

            self.device.cmd_begin_render_pass(cmd, &rp_info, vk::SubpassContents::INLINE);
            self.device.cmd_bind_pipeline(
                cmd, vk::PipelineBindPoint::GRAPHICS, self.graphics_pipeline);
            self.device.cmd_bind_descriptor_sets(
                cmd, vk::PipelineBindPoint::GRAPHICS,
                self.graphics_pipeline_layout, 0, &[self.descriptor_set], &[]);
            self.device.cmd_draw(cmd, NUM_POINTS, 1, 0, 0);
            self.device.cmd_end_render_pass(cmd);

            self.device.end_command_buffer(cmd).unwrap();
        }
    }

    // -----------------------------------------------------------------------
    // Synchronisation
    // -----------------------------------------------------------------------

    fn create_sync_objects(device: &ash::Device)
        -> (Vec<vk::Semaphore>, Vec<vk::Semaphore>, Vec<vk::Fence>)
    {
        let si = vk::SemaphoreCreateInfo::default();
        let fi = vk::FenceCreateInfo::default().flags(vk::FenceCreateFlags::SIGNALED);
        let (mut av, mut dn, mut fn_) = (vec![], vec![], vec![]);
        for _ in 0..MAX_FRAMES_IN_FLIGHT {
            unsafe {
                av .push(device.create_semaphore(&si, None).unwrap());
                dn .push(device.create_semaphore(&si, None).unwrap());
                fn_.push(device.create_fence(&fi,    None).unwrap());
            }
        }
        (av, dn, fn_)
    }

    // -----------------------------------------------------------------------
    // Per-frame rendering (mirrors drawFrame() in the C version)
    // -----------------------------------------------------------------------

    fn draw_frame(&mut self) {
        let f = self.current_frame;

        unsafe {
            self.device
                .wait_for_fences(&[self.in_flight_fences[f]], true, u64::MAX)
                .unwrap();
        }

        let result = unsafe {
            self.swapchain_loader.acquire_next_image(
                self.swapchain, u64::MAX,
                self.image_available_semaphores[f], vk::Fence::null())
        };
        let image_index = match result {
            Ok((idx, _))                            => idx,
            Err(vk::Result::ERROR_OUT_OF_DATE_KHR) => { self.recreate_swapchain(); return; }
            Err(e) => panic!("acquire_next_image failed: {:?}", e),
        };

        if self.images_in_flight[image_index as usize] != vk::Fence::null() {
            unsafe {
                self.device
                    .wait_for_fences(
                        &[self.images_in_flight[image_index as usize]], true, u64::MAX)
                    .unwrap();
            }
        }
        self.images_in_flight[image_index as usize] = self.in_flight_fences[f];

        // ── Animate (CPU side) – mirrors C version's drawFrame() ──────────
        self.anim_time += 0.016;
        self.params.animate(self.anim_time);
        // Write the updated params to the host-coherent UBO (no flush needed).
        Self::upload_params(&self.device, self.params_buffer_memory, &self.params);

        // ── Re-record the command buffer for this frame ───────────────────
        // The C version calls vkResetCommandBuffer + recordCmd every frame.
        let cmd = self.command_buffers[f];
        self.record_frame_commands(cmd, image_index);

        // ── Submit ────────────────────────────────────────────────────────
        let wait_sems   = [self.image_available_semaphores[f]];
        let wait_stages = [vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT];
        let signal_sems = [self.render_finished_semaphores[f]];
        let cmds        = [cmd];
        let submit = vk::SubmitInfo::default()
            .wait_semaphores(&wait_sems)
            .wait_dst_stage_mask(&wait_stages)
            .command_buffers(&cmds)
            .signal_semaphores(&signal_sems);

        unsafe {
            self.device.reset_fences(&[self.in_flight_fences[f]]).unwrap();
            self.device
                .queue_submit(self.graphics_queue, &[submit], self.in_flight_fences[f])
                .unwrap();
        }

        // ── Present ───────────────────────────────────────────────────────
        let swapchains = [self.swapchain];
        let indices    = [image_index];
        let pi = vk::PresentInfoKHR::default()
            .wait_semaphores(&signal_sems)
            .swapchains(&swapchains)
            .image_indices(&indices);

        let result = unsafe {
            self.swapchain_loader.queue_present(self.present_queue, &pi)
        };
        let should_recreate = match result {
            Ok(_)                                  => self.framebuffer_resized,
            Err(vk::Result::SUBOPTIMAL_KHR)        => true,
            Err(vk::Result::ERROR_OUT_OF_DATE_KHR) => true,
            Err(e) => panic!("queue_present failed: {:?}", e),
        };
        if should_recreate {
            self.framebuffer_resized = false;
            self.recreate_swapchain();
        }

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    // -----------------------------------------------------------------------
    // Swapchain recreation on resize
    // -----------------------------------------------------------------------

    fn recreate_swapchain(&mut self) {
        let size = self.window.inner_size();
        if size.width == 0 || size.height == 0 { return; }
        unsafe { self.device.device_wait_idle().unwrap() };
        self.cleanup_swapchain();

        let (sc, images, fmt, extent) = Self::create_swapchain(
            &self.instance, &self.surface_loader, self.surface,
            self.physical_device, &self.swapchain_loader, &self.window);
        self.swapchain              = sc;
        self.swapchain_images       = images;
        self.swapchain_image_format = fmt;
        self.swapchain_extent       = extent;

        self.swapchain_image_views = Self::create_image_views(
            &self.device, &self.swapchain_images, self.swapchain_image_format);
        self.render_pass = Self::create_render_pass(&self.device, self.swapchain_image_format);

        let compiler   = shaderc::Compiler::new().unwrap();
        let vert_spirv = compile_shader(
            &compiler, VERTEX_SHADER_SRC,   shaderc::ShaderKind::Vertex,   "hello.vert");
        let frag_spirv = compile_shader(
            &compiler, FRAGMENT_SHADER_SRC, shaderc::ShaderKind::Fragment, "hello.frag");
        let (gfx_layout, gfx_pipeline) = Self::create_graphics_pipeline(
            &self.device, self.descriptor_set_layout, self.render_pass,
            self.swapchain_extent, &vert_spirv, &frag_spirv);
        self.graphics_pipeline_layout = gfx_layout;
        self.graphics_pipeline        = gfx_pipeline;

        self.swapchain_framebuffers = Self::create_framebuffers(
            &self.device, &self.swapchain_image_views,
            self.render_pass, self.swapchain_extent);

        self.images_in_flight = vec![vk::Fence::null(); self.swapchain_images.len()];
        // Command buffers are re-recorded per-frame; no action needed here.
    }

    fn cleanup_swapchain(&mut self) {
        unsafe {
            for &fb   in &self.swapchain_framebuffers  { self.device.destroy_framebuffer(fb, None); }
            for &view in &self.swapchain_image_views   { self.device.destroy_image_view(view, None); }
            self.device.destroy_pipeline(self.graphics_pipeline, None);
            self.device.destroy_pipeline_layout(self.graphics_pipeline_layout, None);
            self.device.destroy_render_pass(self.render_pass, None);
            self.swapchain_loader.destroy_swapchain(self.swapchain, None);
        }
    }
}

// ---------------------------------------------------------------------------
// Drop
// ---------------------------------------------------------------------------

impl Drop for VulkanApp {
    fn drop(&mut self) {
        unsafe {
            self.device.device_wait_idle().unwrap();
            for &s in &self.image_available_semaphores { self.device.destroy_semaphore(s, None); }
            for &s in &self.render_finished_semaphores { self.device.destroy_semaphore(s, None); }
            for &f in &self.in_flight_fences           { self.device.destroy_fence(f, None); }
            self.cleanup_swapchain();
            self.device.destroy_pipeline(self.compute_pipeline, None);
            self.device.destroy_pipeline_layout(self.compute_pipeline_layout, None);
            self.device.destroy_descriptor_pool(self.descriptor_pool, None);
            self.device.destroy_descriptor_set_layout(self.descriptor_set_layout, None);
            self.device.destroy_buffer(self.pos_buffer, None);
            self.device.free_memory(self.pos_buffer_memory, None);
            self.device.destroy_buffer(self.col_buffer, None);
            self.device.free_memory(self.col_buffer_memory, None);
            self.device.destroy_buffer(self.params_buffer, None);
            self.device.free_memory(self.params_buffer_memory, None);
            self.device.destroy_command_pool(self.command_pool, None);
            self.device.destroy_device(None);
            if let Some(ref dbg) = self.debug_utils_loader {
                dbg.destroy_debug_utils_messenger(self.debug_messenger, None);
            }
            self.surface_loader.destroy_surface(self.surface, None);
            self.instance.destroy_instance(None);
        }
    }
}

// ---------------------------------------------------------------------------
// Debug callback
// ---------------------------------------------------------------------------

unsafe extern "system" fn vulkan_debug_callback(
    _severity: vk::DebugUtilsMessageSeverityFlagsEXT,
    _kind:     vk::DebugUtilsMessageTypeFlagsEXT,
    p_data:    *const vk::DebugUtilsMessengerCallbackDataEXT<'_>,
    _user:     *mut std::ffi::c_void,
) -> vk::Bool32 {
    eprintln!("[Vulkan] {}", CStr::from_ptr((*p_data).p_message).to_string_lossy());
    vk::FALSE
}

// ---------------------------------------------------------------------------
// winit ApplicationHandler
// ---------------------------------------------------------------------------

struct App { vulkan: Option<VulkanApp> }

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.vulkan.is_none() {
            self.vulkan = Some(VulkanApp::new(event_loop));
        }
    }

    fn window_event(
        &mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent,
    ) {
        let vulkan = match self.vulkan.as_mut() { Some(v) => v, None => return };
        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::Resized(_)     => vulkan.framebuffer_resized = true,
            WindowEvent::RedrawRequested => {
                vulkan.draw_frame();
                vulkan.window.request_redraw();
            }
            _ => {}
        }
    }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

fn main() {
    let event_loop = EventLoop::new().unwrap();
    event_loop.set_control_flow(ControlFlow::Poll);
    let mut app = App { vulkan: None };
    event_loop.run_app(&mut app).unwrap();
}
