//! Vulkan 1.4 Ray Marching in Rust using ash + winit
//! Features: Ray marching, SDF shapes, soft shadows, ambient occlusion, animated objects

use ash::ext::debug_utils;
use ash::khr::{surface, swapchain};
use ash::vk;
use raw_window_handle::{HasDisplayHandle, HasWindowHandle};
use std::ffi::{CStr, CString};
use std::mem;
use winit::application::ApplicationHandler;
use winit::dpi::PhysicalSize;
use winit::event::WindowEvent;
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::window::{Window, WindowId};

const WIDTH: u32 = 800;
const HEIGHT: u32 = 600;
const MAX_FRAMES_IN_FLIGHT: usize = 2;

// Vulkan 1.4 API version
const API_VERSION_1_4: u32 = vk::make_api_version(0, 1, 4, 0);

#[cfg(debug_assertions)]
const ENABLE_VALIDATION_LAYERS: bool = true;
#[cfg(not(debug_assertions))]
const ENABLE_VALIDATION_LAYERS: bool = false;

const VALIDATION_LAYERS: &[&CStr] = unsafe {
    &[CStr::from_bytes_with_nul_unchecked(
        b"VK_LAYER_KHRONOS_validation\0",
    )]
};

// Convert CStr to raw pointers for Vulkan API
fn get_layer_ptrs(layers: &[&CStr]) -> Vec<*const i8> {
    layers.iter().map(|layer| layer.as_ptr()).collect()
}

// Push constant structure - matches GLSL std140 layout
#[repr(C)]
struct PushConstants {
    iTime: f32,
    padding: f32,
    iResolution: [f32; 2],
}

// Vertex shader: Full-screen triangle
const VERTEX_SHADER_SOURCE: &str = r#"
#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec2 fragCoord;

// Fullscreen triangle technique (3 vertices cover entire screen)
vec2 positions[3] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 3.0, -1.0),
    vec2(-1.0,  3.0)
);

void main() {
    vec2 pos = positions[gl_VertexIndex];
    gl_Position = vec4(pos, 0.0, 1.0);
    // Output UV in [0, 1] range with Y flipped to match DX12/OpenGL convention
    fragCoord = vec2(pos.x * 0.5 + 0.5, 1.0 - (pos.y * 0.5 + 0.5));
}
"#;

// Fragment shader: Ray marching with SDF
const FRAGMENT_SHADER_SOURCE: &str = r#"
#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec2 fragCoord;
layout(location = 0) out vec4 outColor;

// Push constants for time and resolution
layout(push_constant) uniform PushConstants {
    float iTime;
    float padding;
    vec2 iResolution;
} pc;

const int MAX_STEPS = 100;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.001;

// Signed Distance Functions
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Smooth minimum for blending shapes
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Scene distance function
float GetDist(vec3 p) {
    // Animated sphere
    float sphere = sdSphere(p - vec3(sin(pc.iTime) * 1.5, 0.5 + sin(pc.iTime * 2.0) * 0.3, 0.0), 0.5);
    
    // Rotating torus - match HLSL rotation method
    float angle = pc.iTime * 0.5;
    vec3 torusPos = p - vec3(0.0, 0.5, 0.0);
    float cosA = cos(angle);
    float sinA = sin(angle);
    vec2 rotatedXZ = vec2(cosA * torusPos.x - sinA * torusPos.z, sinA * torusPos.x + cosA * torusPos.z);
    torusPos.x = rotatedXZ.x;
    torusPos.z = rotatedXZ.y;
    
    float angle2 = angle * 0.7;
    float cosA2 = cos(angle2);
    float sinA2 = sin(angle2);
    vec2 rotatedXY = vec2(cosA2 * torusPos.x - sinA2 * torusPos.y, sinA2 * torusPos.x + cosA2 * torusPos.y);
    torusPos.x = rotatedXY.x;
    torusPos.y = rotatedXY.y;
    
    float torus = sdTorus(torusPos, vec2(0.8, 0.2));  // radius 0.8 (was 0.6)
    
    // Ground plane
    float plane = p.y + 0.5;
    
    // Combine with smooth min
    float d = smin(sphere, torus, 0.3);
    d = min(d, plane);
    
    return d;
}

// Raymarching
float RayMarch(vec3 ro, vec3 rd) {
    float d = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d;
        float ds = GetDist(p);
        d += ds;
        if (d > MAX_DIST || ds < SURF_DIST) break;
    }
    return d;
}

// Calculate normal
vec3 GetNormal(vec3 p) {
    float d = GetDist(p);
    vec2 e = vec2(0.001, 0.0);
    vec3 n = d - vec3(
        GetDist(p - e.xyy),
        GetDist(p - e.yxy),
        GetDist(p - e.yyx)
    );
    return normalize(n);
}

// Soft shadow - 64 iterations (was 32)
float GetShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
    float res = 1.0;
    float t = mint;
    for (int i = 0; i < 64; i++) {
        if (t >= maxt) break;
        float h = GetDist(ro + rd * t);
        if (h < 0.001) return 0.0;
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

// Ambient occlusion
float GetAO(vec3 p, vec3 n) {
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = GetDist(p + h * n);
        occ += (h - d) * sca;
        sca *= 0.95;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

void main() {
    // UV: match HLSL range [-0.5, 0.5] (was [-1, 1])
    vec2 uv = fragCoord - 0.5;
    uv.x *= pc.iResolution.x / pc.iResolution.y;
    
    // Camera setup - match HLSL exactly
    vec3 ro = vec3(0.0, 1.5, -4.0);
    vec3 rd = normalize(vec3(uv.x, uv.y, 1.0));
    
    // Light position - match HLSL (z = -2.0, was +2.0)
    vec3 lightPos = vec3(3.0, 5.0, -2.0);
    
    // Raymarching
    float d = RayMarch(ro, rd);
    
    vec3 col = vec3(0.0);
    
    if (d < MAX_DIST) {
        vec3 p = ro + rd * d;
        vec3 n = GetNormal(p);
        vec3 l = normalize(lightPos - p);
        vec3 v = normalize(ro - p);
        vec3 r = reflect(-l, n);
        
        // Material color - match HLSL (was 0.4, 0.6, 0.8)
        vec3 matCol = vec3(0.4, 0.6, 0.9);
        if (p.y < -0.49) {
            // Checkerboard floor - match HLSL colors
            float check = mod(floor(p.x) + floor(p.z), 2.0);
            matCol = mix(vec3(0.2, 0.2, 0.2), vec3(0.8, 0.8, 0.8), check);
        }
        
        // Lighting
        float diff = max(dot(n, l), 0.0);
        float spec = pow(max(dot(r, v), 0.0), 32.0);
        float ao = GetAO(p, n);
        float shadow = GetShadow(p + n * 0.01, l, 0.01, length(lightPos - p), 16.0);
        
        // Ambient
        vec3 ambient = vec3(0.1, 0.12, 0.15);
        
        col = matCol * (ambient * ao + diff * shadow) + vec3(1.0) * spec * shadow * 0.5;
        
        // Fog
        col = mix(col, vec3(0.05, 0.05, 0.1), 1.0 - exp(-0.02 * d * d));
    } else {
        // Background gradient - match HLSL
        col = mix(vec3(0.1, 0.1, 0.15), vec3(0.02, 0.02, 0.05), fragCoord.y);
    }
    
    // Gamma correction
    col = pow(col, vec3(0.4545));
    
    outColor = vec4(col, 1.0);
}
"#;

/// Compile GLSL shader source to SPIR-V at runtime
fn compile_shader(
    compiler: &shaderc::Compiler,
    source: &str,
    kind: shaderc::ShaderKind,
    name: &str,
) -> Vec<u32> {
    let mut options = shaderc::CompileOptions::new().unwrap();
    options.set_target_env(
        shaderc::TargetEnv::Vulkan,
        shaderc::EnvVersion::Vulkan1_3 as u32,
    );

    let result = compiler
        .compile_into_spirv(source, kind, name, "main", Some(&options))
        .expect(&format!("Failed to compile shader: {}", name));

    result.as_binary().to_vec()
}

struct QueueFamilyIndices {
    graphics_family: Option<u32>,
    present_family: Option<u32>,
}

impl QueueFamilyIndices {
    fn is_complete(&self) -> bool {
        self.graphics_family.is_some() && self.present_family.is_some()
    }
}

struct SwapChainSupportDetails {
    capabilities: vk::SurfaceCapabilitiesKHR,
    formats: Vec<vk::SurfaceFormatKHR>,
    present_modes: Vec<vk::PresentModeKHR>,
}

struct VulkanApp {
    window: Window,

    _entry: ash::Entry,
    instance: ash::Instance,
    debug_utils_loader: Option<debug_utils::Instance>,
    debug_messenger: vk::DebugUtilsMessengerEXT,
    surface_loader: surface::Instance,
    surface: vk::SurfaceKHR,

    physical_device: vk::PhysicalDevice,
    device: ash::Device,

    graphics_queue: vk::Queue,
    present_queue: vk::Queue,

    swapchain_loader: swapchain::Device,
    swapchain: vk::SwapchainKHR,
    swapchain_images: Vec<vk::Image>,
    swapchain_image_format: vk::Format,
    swapchain_extent: vk::Extent2D,
    swapchain_image_views: Vec<vk::ImageView>,
    swapchain_framebuffers: Vec<vk::Framebuffer>,

    render_pass: vk::RenderPass,
    pipeline_layout: vk::PipelineLayout,
    graphics_pipeline: vk::Pipeline,

    command_pool: vk::CommandPool,
    command_buffers: Vec<vk::CommandBuffer>,

    image_available_semaphores: Vec<vk::Semaphore>,
    render_finished_semaphores: Vec<vk::Semaphore>,
    in_flight_fences: Vec<vk::Fence>,
    images_in_flight: Vec<vk::Fence>,
    current_frame: usize,

    framebuffer_resized: bool,
    start_time: std::time::Instant,
}

impl VulkanApp {
    fn new(event_loop: &ActiveEventLoop) -> Self {
        let window_attributes = Window::default_attributes()
            .with_title("Vulkan 1.4 Ray Marching (Rust)")
            .with_inner_size(PhysicalSize::new(WIDTH, HEIGHT));

        let window = event_loop.create_window(window_attributes).unwrap();

        let entry = unsafe { ash::Entry::load().expect("Failed to load Vulkan") };

        let instance = Self::create_instance(&entry, &window);

        let (debug_utils_loader, debug_messenger) = if ENABLE_VALIDATION_LAYERS {
            Self::setup_debug_messenger(&entry, &instance)
        } else {
            (None, vk::DebugUtilsMessengerEXT::null())
        };

        let surface_loader = surface::Instance::new(&entry, &instance);
        let surface = unsafe {
            ash_window::create_surface(
                &entry,
                &instance,
                window.display_handle().unwrap().as_raw(),
                window.window_handle().unwrap().as_raw(),
                None,
            )
            .expect("Failed to create surface")
        };

        let physical_device = Self::pick_physical_device(&instance, &surface_loader, surface);
        let (device, graphics_queue, present_queue) =
            Self::create_logical_device(&instance, physical_device, &surface_loader, surface);

        let swapchain_loader = swapchain::Device::new(&instance, &device);
        let (swapchain, swapchain_images, swapchain_image_format, swapchain_extent) =
            Self::create_swapchain(
                &instance,
                &surface_loader,
                surface,
                physical_device,
                &swapchain_loader,
                &window,
            );

        let swapchain_image_views =
            Self::create_image_views(&device, &swapchain_images, swapchain_image_format);

        let render_pass = Self::create_render_pass(&device, swapchain_image_format);
        let (pipeline_layout, graphics_pipeline) =
            Self::create_graphics_pipeline(&device, render_pass, swapchain_extent);

        let swapchain_framebuffers = Self::create_framebuffers(
            &device,
            &swapchain_image_views,
            render_pass,
            swapchain_extent,
        );

        let command_pool =
            Self::create_command_pool(&instance, physical_device, &device, &surface_loader, surface);
        let command_buffers = Self::create_command_buffers(
            &device,
            command_pool,
            &swapchain_framebuffers,
        );

        let (image_available_semaphores, render_finished_semaphores, in_flight_fences) =
            Self::create_sync_objects(&device);
        let images_in_flight = vec![vk::Fence::null(); swapchain_images.len()];

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
            render_pass,
            pipeline_layout,
            graphics_pipeline,
            command_pool,
            command_buffers,
            image_available_semaphores,
            render_finished_semaphores,
            in_flight_fences,
            images_in_flight,
            current_frame: 0,
            framebuffer_resized: false,
            start_time: std::time::Instant::now(),
        }
    }

    fn create_instance(entry: &ash::Entry, window: &Window) -> ash::Instance {
        let app_name = CString::new("Vulkan Ray Marching").unwrap();
        let engine_name = CString::new("No Engine").unwrap();

        let app_info = vk::ApplicationInfo::default()
            .application_name(&app_name)
            .application_version(vk::make_api_version(0, 1, 0, 0))
            .engine_name(&engine_name)
            .engine_version(vk::make_api_version(0, 1, 0, 0))
            .api_version(API_VERSION_1_4);

        let mut instance_extensions =
            ash_window::enumerate_required_extensions(window.display_handle().unwrap().as_raw())
                .unwrap()
                .to_vec();

        if ENABLE_VALIDATION_LAYERS {
            instance_extensions.push(debug_utils::NAME.as_ptr());
        }

        let layer_ptrs = get_layer_ptrs(VALIDATION_LAYERS);

        let create_info = if ENABLE_VALIDATION_LAYERS {
            vk::InstanceCreateInfo::default()
                .application_info(&app_info)
                .enabled_extension_names(&instance_extensions)
                .enabled_layer_names(&layer_ptrs)
        } else {
            vk::InstanceCreateInfo::default()
                .application_info(&app_info)
                .enabled_extension_names(&instance_extensions)
        };

        unsafe { entry.create_instance(&create_info, None).unwrap() }
    }

    fn setup_debug_messenger(
        entry: &ash::Entry,
        instance: &ash::Instance,
    ) -> (Option<debug_utils::Instance>, vk::DebugUtilsMessengerEXT) {
        let debug_utils_loader = debug_utils::Instance::new(entry, instance);

        let create_info = vk::DebugUtilsMessengerCreateInfoEXT::default()
            .message_severity(
                vk::DebugUtilsMessageSeverityFlagsEXT::ERROR
                    | vk::DebugUtilsMessageSeverityFlagsEXT::WARNING,
            )
            .message_type(
                vk::DebugUtilsMessageTypeFlagsEXT::GENERAL
                    | vk::DebugUtilsMessageTypeFlagsEXT::VALIDATION
                    | vk::DebugUtilsMessageTypeFlagsEXT::PERFORMANCE,
            )
            .pfn_user_callback(Some(vulkan_debug_callback));

        let messenger = unsafe {
            debug_utils_loader
                .create_debug_utils_messenger(&create_info, None)
                .unwrap()
        };

        (Some(debug_utils_loader), messenger)
    }

    fn pick_physical_device(
        instance: &ash::Instance,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> vk::PhysicalDevice {
        let devices = unsafe { instance.enumerate_physical_devices().unwrap() };

        devices
            .iter()
            .find(|&&device| Self::is_device_suitable(instance, device, surface_loader, surface))
            .copied()
            .expect("Failed to find suitable GPU!")
    }

    fn is_device_suitable(
        instance: &ash::Instance,
        device: vk::PhysicalDevice,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> bool {
        let indices = Self::find_queue_families(instance, device, surface_loader, surface);

        indices.is_complete()
            && Self::check_device_extension_support(instance, device)
            && !Self::query_swap_chain_support(instance, device, surface_loader, surface)
                .formats
                .is_empty()
            && !Self::query_swap_chain_support(instance, device, surface_loader, surface)
                .present_modes
                .is_empty()
    }

    fn check_device_extension_support(instance: &ash::Instance, device: vk::PhysicalDevice) -> bool {
        let available_extensions = unsafe {
            instance
                .enumerate_device_extension_properties(device)
                .unwrap()
        };

        let available_extension_names: Vec<String> = available_extensions
            .iter()
            .map(|ext| {
                unsafe { CStr::from_ptr(ext.extension_name.as_ptr()) }
                    .to_string_lossy()
                    .to_string()
            })
            .collect();

        let swapchain_str = swapchain::NAME.to_string_lossy().to_string();
        available_extension_names.iter().any(|available| available == &swapchain_str)
    }

    fn find_queue_families(
        instance: &ash::Instance,
        device: vk::PhysicalDevice,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> QueueFamilyIndices {
        let properties = unsafe { instance.get_physical_device_queue_family_properties(device) };

        let mut indices = QueueFamilyIndices {
            graphics_family: None,
            present_family: None,
        };

        for (index, family) in properties.iter().enumerate() {
            if family.queue_flags.contains(vk::QueueFlags::GRAPHICS) {
                indices.graphics_family = Some(index as u32);
            }

            let present_support = unsafe {
                surface_loader
                    .get_physical_device_surface_support(device, index as u32, surface)
                    .unwrap()
            };
            if present_support {
                indices.present_family = Some(index as u32);
            }

            if indices.is_complete() {
                break;
            }
        }

        indices
    }

    fn query_swap_chain_support(
        _instance: &ash::Instance,
        device: vk::PhysicalDevice,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> SwapChainSupportDetails {
        let capabilities =
            unsafe { surface_loader.get_physical_device_surface_capabilities(device, surface).unwrap() };
        let formats =
            unsafe { surface_loader.get_physical_device_surface_formats(device, surface).unwrap() };
        let present_modes =
            unsafe {
                surface_loader.get_physical_device_surface_present_modes(device, surface).unwrap()
            };

        SwapChainSupportDetails {
            capabilities,
            formats,
            present_modes,
        }
    }

    fn create_logical_device(
        instance: &ash::Instance,
        physical_device: vk::PhysicalDevice,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> (ash::Device, vk::Queue, vk::Queue) {
        let indices = Self::find_queue_families(instance, physical_device, surface_loader, surface);

        let queue_priorities = vec![1.0];
        let mut queue_create_infos = vec![];
        let mut unique_queue_families = vec![indices.graphics_family.unwrap()];
        if let Some(present_family) = indices.present_family {
            if present_family != indices.graphics_family.unwrap() {
                unique_queue_families.push(present_family);
            }
        }

        for &queue_family in &unique_queue_families {
            let queue_create_info = vk::DeviceQueueCreateInfo::default()
                .queue_family_index(queue_family)
                .queue_priorities(&queue_priorities);
            queue_create_infos.push(queue_create_info);
        }

        let device_extensions = [swapchain::NAME.as_ptr()];
        let device_features = vk::PhysicalDeviceFeatures::default();

        let device_create_info = vk::DeviceCreateInfo::default()
            .queue_create_infos(&queue_create_infos)
            .enabled_features(&device_features)
            .enabled_extension_names(&device_extensions);

        let device = unsafe {
            instance
                .create_device(physical_device, &device_create_info, None)
                .unwrap()
        };

        let graphics_queue = unsafe { device.get_device_queue(indices.graphics_family.unwrap(), 0) };
        let present_queue = unsafe { device.get_device_queue(indices.present_family.unwrap(), 0) };

        (device, graphics_queue, present_queue)
    }

    fn create_swapchain(
        instance: &ash::Instance,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
        physical_device: vk::PhysicalDevice,
        swapchain_loader: &swapchain::Device,
        window: &Window,
    ) -> (vk::SwapchainKHR, Vec<vk::Image>, vk::Format, vk::Extent2D) {
        let support = Self::query_swap_chain_support(instance, physical_device, surface_loader, surface);

        let surface_format = *support
            .formats
            .iter()
            .find(|format| {
                format.format == vk::Format::B8G8R8A8_UNORM
                    && format.color_space == vk::ColorSpaceKHR::SRGB_NONLINEAR
            })
            .unwrap_or(&support.formats[0]);

        let present_mode = support
            .present_modes
            .iter()
            .find(|&&mode| mode == vk::PresentModeKHR::MAILBOX)
            .copied()
            .unwrap_or(vk::PresentModeKHR::FIFO);

        let extent = Self::choose_swap_extent(&support.capabilities, window);

        let mut image_count = support.capabilities.min_image_count + 1;
        if support.capabilities.max_image_count > 0
            && image_count > support.capabilities.max_image_count
        {
            image_count = support.capabilities.max_image_count;
        }

        let create_info = vk::SwapchainCreateInfoKHR::default()
            .surface(surface)
            .min_image_count(image_count)
            .image_format(surface_format.format)
            .image_color_space(surface_format.color_space)
            .image_extent(extent)
            .image_array_layers(1)
            .image_usage(vk::ImageUsageFlags::COLOR_ATTACHMENT)
            .pre_transform(support.capabilities.current_transform)
            .composite_alpha(vk::CompositeAlphaFlagsKHR::OPAQUE)
            .present_mode(present_mode)
            .clipped(true)
            .old_swapchain(vk::SwapchainKHR::null());

        let swapchain = unsafe { swapchain_loader.create_swapchain(&create_info, None).unwrap() };
        let swapchain_images = unsafe { swapchain_loader.get_swapchain_images(swapchain).unwrap() };

        (swapchain, swapchain_images, surface_format.format, extent)
    }

    fn choose_swap_extent(
        capabilities: &vk::SurfaceCapabilitiesKHR,
        window: &Window,
    ) -> vk::Extent2D {
        if capabilities.current_extent.width != u32::MAX {
            return capabilities.current_extent;
        }

        let PhysicalSize { width, height } = window.inner_size();
        vk::Extent2D {
            width: width.clamp(
                capabilities.min_image_extent.width,
                capabilities.max_image_extent.width,
            ),
            height: height.clamp(
                capabilities.min_image_extent.height,
                capabilities.max_image_extent.height,
            ),
        }
    }

    fn create_image_views(
        device: &ash::Device,
        swapchain_images: &[vk::Image],
        swapchain_image_format: vk::Format,
    ) -> Vec<vk::ImageView> {
        swapchain_images
            .iter()
            .map(|&image| {
                let create_info = vk::ImageViewCreateInfo::default()
                    .image(image)
                    .view_type(vk::ImageViewType::TYPE_2D)
                    .format(swapchain_image_format)
                    .components(vk::ComponentMapping {
                        r: vk::ComponentSwizzle::IDENTITY,
                        g: vk::ComponentSwizzle::IDENTITY,
                        b: vk::ComponentSwizzle::IDENTITY,
                        a: vk::ComponentSwizzle::IDENTITY,
                    })
                    .subresource_range(vk::ImageSubresourceRange {
                        aspect_mask: vk::ImageAspectFlags::COLOR,
                        base_mip_level: 0,
                        level_count: 1,
                        base_array_layer: 0,
                        layer_count: 1,
                    });

                unsafe { device.create_image_view(&create_info, None).unwrap() }
            })
            .collect()
    }

    fn create_render_pass(device: &ash::Device, swapchain_image_format: vk::Format) -> vk::RenderPass {
        let color_attachment = vk::AttachmentDescription::default()
            .format(swapchain_image_format)
            .samples(vk::SampleCountFlags::TYPE_1)
            .load_op(vk::AttachmentLoadOp::CLEAR)
            .store_op(vk::AttachmentStoreOp::STORE)
            .stencil_load_op(vk::AttachmentLoadOp::DONT_CARE)
            .stencil_store_op(vk::AttachmentStoreOp::DONT_CARE)
            .initial_layout(vk::ImageLayout::UNDEFINED)
            .final_layout(vk::ImageLayout::PRESENT_SRC_KHR);

        let color_attachment_ref = vk::AttachmentReference::default()
            .attachment(0)
            .layout(vk::ImageLayout::COLOR_ATTACHMENT_OPTIMAL);

        let attachments = [color_attachment];
        let color_attachments = [color_attachment_ref];
        
        let subpass = vk::SubpassDescription::default()
            .pipeline_bind_point(vk::PipelineBindPoint::GRAPHICS)
            .color_attachments(&color_attachments);

        let dependency = vk::SubpassDependency::default()
            .src_subpass(vk::SUBPASS_EXTERNAL)
            .dst_subpass(0)
            .src_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .src_access_mask(vk::AccessFlags::empty())
            .dst_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .dst_access_mask(vk::AccessFlags::COLOR_ATTACHMENT_WRITE);

        let subpasses = [subpass];
        let dependencies = [dependency];

        let render_pass_info = vk::RenderPassCreateInfo::default()
            .attachments(&attachments)
            .subpasses(&subpasses)
            .dependencies(&dependencies);

        unsafe { device.create_render_pass(&render_pass_info, None).unwrap() }
    }

    fn create_graphics_pipeline(
        device: &ash::Device,
        render_pass: vk::RenderPass,
        extent: vk::Extent2D,
    ) -> (vk::PipelineLayout, vk::Pipeline) {
        let compiler = shaderc::Compiler::new().unwrap();

        let vert_code = compile_shader(&compiler, VERTEX_SHADER_SOURCE, shaderc::ShaderKind::Vertex, "vertex");
        let frag_code = compile_shader(&compiler, FRAGMENT_SHADER_SOURCE, shaderc::ShaderKind::Fragment, "fragment");

        let vert_module = unsafe {
            device
                .create_shader_module(
                    &vk::ShaderModuleCreateInfo::default().code(&vert_code),
                    None,
                )
                .unwrap()
        };

        let frag_module = unsafe {
            device
                .create_shader_module(
                    &vk::ShaderModuleCreateInfo::default().code(&frag_code),
                    None,
                )
                .unwrap()
        };

        let vert_stage_info = vk::PipelineShaderStageCreateInfo::default()
            .stage(vk::ShaderStageFlags::VERTEX)
            .module(vert_module)
            .name(CStr::from_bytes_with_nul(b"main\0").unwrap());

        let frag_stage_info = vk::PipelineShaderStageCreateInfo::default()
            .stage(vk::ShaderStageFlags::FRAGMENT)
            .module(frag_module)
            .name(CStr::from_bytes_with_nul(b"main\0").unwrap());

        let shader_stages = [vert_stage_info, frag_stage_info];

        let vertex_input_info = vk::PipelineVertexInputStateCreateInfo::default();

        let input_assembly = vk::PipelineInputAssemblyStateCreateInfo::default()
            .topology(vk::PrimitiveTopology::TRIANGLE_LIST)
            .primitive_restart_enable(false);

        let viewport = vk::Viewport {
            x: 0.0,
            y: 0.0,
            width: extent.width as f32,
            height: extent.height as f32,
            min_depth: 0.0,
            max_depth: 1.0,
        };

        let scissor = vk::Rect2D {
            offset: vk::Offset2D { x: 0, y: 0 },
            extent,
        };

        let viewports = [viewport];
        let scissors = [scissor];

        let viewport_state = vk::PipelineViewportStateCreateInfo::default()
            .viewports(&viewports)
            .scissors(&scissors);

        let rasterizer = vk::PipelineRasterizationStateCreateInfo::default()
            .depth_clamp_enable(false)
            .rasterizer_discard_enable(false)
            .polygon_mode(vk::PolygonMode::FILL)
            .line_width(1.0)
            .cull_mode(vk::CullModeFlags::BACK)
            .front_face(vk::FrontFace::CLOCKWISE)
            .depth_bias_enable(false);

        let multisampling = vk::PipelineMultisampleStateCreateInfo::default()
            .sample_shading_enable(false)
            .rasterization_samples(vk::SampleCountFlags::TYPE_1);

        let color_blend_attachment = vk::PipelineColorBlendAttachmentState::default()
            .color_write_mask(vk::ColorComponentFlags::RGBA)
            .blend_enable(false);

        let color_blend_attachments = [color_blend_attachment];

        let color_blending = vk::PipelineColorBlendStateCreateInfo::default()
            .logic_op_enable(false)
            .attachments(&color_blend_attachments);

        // Push constant range for time and resolution
        let push_constant_range = vk::PushConstantRange {
            stage_flags: vk::ShaderStageFlags::FRAGMENT,
            offset: 0,
            size: mem::size_of::<PushConstants>() as u32,
        };

        let push_constant_ranges = [push_constant_range];

        let pipeline_layout_info = vk::PipelineLayoutCreateInfo::default()
            .push_constant_ranges(&push_constant_ranges);

        let pipeline_layout = unsafe {
            device
                .create_pipeline_layout(&pipeline_layout_info, None)
                .unwrap()
        };

        let graphics_pipeline_info = vk::GraphicsPipelineCreateInfo::default()
            .stages(&shader_stages)
            .vertex_input_state(&vertex_input_info)
            .input_assembly_state(&input_assembly)
            .viewport_state(&viewport_state)
            .rasterization_state(&rasterizer)
            .multisample_state(&multisampling)
            .color_blend_state(&color_blending)
            .layout(pipeline_layout)
            .render_pass(render_pass)
            .subpass(0);

        let graphics_pipeline = unsafe {
            device
                .create_graphics_pipelines(vk::PipelineCache::null(), &[graphics_pipeline_info], None)
                .unwrap()[0]
        };

        unsafe {
            device.destroy_shader_module(vert_module, None);
            device.destroy_shader_module(frag_module, None);
        }

        (pipeline_layout, graphics_pipeline)
    }

    fn create_framebuffers(
        device: &ash::Device,
        image_views: &[vk::ImageView],
        render_pass: vk::RenderPass,
        extent: vk::Extent2D,
    ) -> Vec<vk::Framebuffer> {
        image_views
            .iter()
            .map(|&image_view| {
                let attachments = [image_view];
                let framebuffer_info = vk::FramebufferCreateInfo::default()
                    .render_pass(render_pass)
                    .attachments(&attachments)
                    .width(extent.width)
                    .height(extent.height)
                    .layers(1);

                unsafe { device.create_framebuffer(&framebuffer_info, None).unwrap() }
            })
            .collect()
    }

    fn create_command_pool(
        instance: &ash::Instance,
        physical_device: vk::PhysicalDevice,
        device: &ash::Device,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> vk::CommandPool {
        let queue_families =
            Self::find_queue_families(instance, physical_device, surface_loader, surface);

        let pool_info = vk::CommandPoolCreateInfo::default()
            .queue_family_index(queue_families.graphics_family.unwrap())
            .flags(vk::CommandPoolCreateFlags::RESET_COMMAND_BUFFER);

        unsafe { device.create_command_pool(&pool_info, None).unwrap() }
    }

    fn create_command_buffers(
        device: &ash::Device,
        command_pool: vk::CommandPool,
        framebuffers: &[vk::Framebuffer],
    ) -> Vec<vk::CommandBuffer> {
        let allocate_info = vk::CommandBufferAllocateInfo::default()
            .command_pool(command_pool)
            .level(vk::CommandBufferLevel::PRIMARY)
            .command_buffer_count(framebuffers.len() as u32);

        unsafe { device.allocate_command_buffers(&allocate_info).unwrap() }
    }

    fn create_sync_objects(
        device: &ash::Device,
    ) -> (Vec<vk::Semaphore>, Vec<vk::Semaphore>, Vec<vk::Fence>) {
        let mut image_available = vec![];
        let mut render_finished = vec![];
        let mut in_flight = vec![];

        for _ in 0..MAX_FRAMES_IN_FLIGHT {
            let semaphore_info = vk::SemaphoreCreateInfo::default();
            let fence_info = vk::FenceCreateInfo::default().flags(vk::FenceCreateFlags::SIGNALED);

            unsafe {
                image_available.push(device.create_semaphore(&semaphore_info, None).unwrap());
                render_finished.push(device.create_semaphore(&semaphore_info, None).unwrap());
                in_flight.push(device.create_fence(&fence_info, None).unwrap());
            }
        }

        (image_available, render_finished, in_flight)
    }

    fn record_command_buffer(
        &self,
        command_buffer: vk::CommandBuffer,
        framebuffer: vk::Framebuffer,
        time: f32,
    ) {
        let begin_info = vk::CommandBufferBeginInfo::default()
            .flags(vk::CommandBufferUsageFlags::ONE_TIME_SUBMIT);

        unsafe {
            self.device.begin_command_buffer(command_buffer, &begin_info).unwrap();

            let clear_color = vk::ClearValue {
                color: vk::ClearColorValue {
                    float32: [0.0, 0.0, 0.0, 1.0],
                },
            };

            let clear_values = [clear_color];

            let render_pass_begin_info = vk::RenderPassBeginInfo::default()
                .render_pass(self.render_pass)
                .framebuffer(framebuffer)
                .render_area(vk::Rect2D {
                    offset: vk::Offset2D { x: 0, y: 0 },
                    extent: self.swapchain_extent,
                })
                .clear_values(&clear_values);

            self.device.cmd_begin_render_pass(
                command_buffer,
                &render_pass_begin_info,
                vk::SubpassContents::INLINE,
            );

            self.device.cmd_bind_pipeline(
                command_buffer,
                vk::PipelineBindPoint::GRAPHICS,
                self.graphics_pipeline,
            );

            // Push constants for time and resolution
            let push_constants = PushConstants {
                iTime: time,
                padding: 0.0,
                iResolution: [
                    self.swapchain_extent.width as f32,
                    self.swapchain_extent.height as f32,
                ],
            };

            self.device.cmd_push_constants(
                command_buffer,
                self.pipeline_layout,
                vk::ShaderStageFlags::FRAGMENT,
                0,
                std::slice::from_raw_parts(
                    &push_constants as *const _ as *const u8,
                    std::mem::size_of::<PushConstants>(),
                ),
            );

            self.device.cmd_draw(command_buffer, 3, 1, 0, 0);
            self.device.cmd_end_render_pass(command_buffer);
            self.device.end_command_buffer(command_buffer).unwrap();
        }
    }

    fn draw_frame(&mut self) {
        unsafe {
            self.device
                .wait_for_fences(&[self.in_flight_fences[self.current_frame]], true, u64::MAX)
                .unwrap();
        }

        let result = unsafe {
            self.swapchain_loader.acquire_next_image(
                self.swapchain,
                u64::MAX,
                self.image_available_semaphores[self.current_frame],
                vk::Fence::null(),
            )
        };

        let image_index = match result {
            Ok((index, _)) => index,
            Err(vk::Result::ERROR_OUT_OF_DATE_KHR) => {
                self.recreate_swapchain();
                return;
            }
            Err(e) => panic!("Failed to acquire swap chain image: {:?}", e),
        };

        if self.images_in_flight[image_index as usize] != vk::Fence::null() {
            unsafe {
                self.device
                    .wait_for_fences(&[self.images_in_flight[image_index as usize]], true, u64::MAX)
                    .unwrap();
            }
        }
        self.images_in_flight[image_index as usize] = self.in_flight_fences[self.current_frame];

        // Record command buffer with current time
        let elapsed = self.start_time.elapsed().as_secs_f32();
        self.record_command_buffer(
            self.command_buffers[image_index as usize],
            self.swapchain_framebuffers[image_index as usize],
            elapsed,
        );

        let wait_semaphores = [self.image_available_semaphores[self.current_frame]];
        let wait_stages = [vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT];
        let signal_semaphores = [self.render_finished_semaphores[self.current_frame]];
        let command_buffers = [self.command_buffers[image_index as usize]];

        let submit_info = vk::SubmitInfo::default()
            .wait_semaphores(&wait_semaphores)
            .wait_dst_stage_mask(&wait_stages)
            .command_buffers(&command_buffers)
            .signal_semaphores(&signal_semaphores);

        unsafe {
            self.device
                .reset_fences(&[self.in_flight_fences[self.current_frame]])
                .unwrap();
            self.device
                .queue_submit(
                    self.graphics_queue,
                    &[submit_info],
                    self.in_flight_fences[self.current_frame],
                )
                .unwrap();
        }

        let swapchains = [self.swapchain];
        let image_indices = [image_index];

        let present_info = vk::PresentInfoKHR::default()
            .wait_semaphores(&signal_semaphores)
            .swapchains(&swapchains)
            .image_indices(&image_indices);

        let result = unsafe { self.swapchain_loader.queue_present(self.present_queue, &present_info) };

        let should_recreate = match result {
            Ok(_) => self.framebuffer_resized,
            Err(vk::Result::SUBOPTIMAL_KHR) => true,
            Err(vk::Result::ERROR_OUT_OF_DATE_KHR) => true,
            Err(e) => panic!("Failed to present swap chain image: {:?}", e),
        };

        if should_recreate {
            self.framebuffer_resized = false;
            self.recreate_swapchain();
        }

        self.current_frame = (self.current_frame + 1) % MAX_FRAMES_IN_FLIGHT;
    }

    fn recreate_swapchain(&mut self) {
        let size = self.window.inner_size();
        if size.width == 0 || size.height == 0 {
            return;
        }

        unsafe { self.device.device_wait_idle().unwrap() };

        self.cleanup_swapchain();

        let (swapchain, images, format, extent) = Self::create_swapchain(
            &self.instance,
            &self.surface_loader,
            self.surface,
            self.physical_device,
            &self.swapchain_loader,
            &self.window,
        );
        self.swapchain = swapchain;
        self.swapchain_images = images;
        self.swapchain_image_format = format;
        self.swapchain_extent = extent;

        self.swapchain_image_views =
            Self::create_image_views(&self.device, &self.swapchain_images, self.swapchain_image_format);

        self.render_pass = Self::create_render_pass(&self.device, self.swapchain_image_format);

        let (layout, pipeline) =
            Self::create_graphics_pipeline(&self.device, self.render_pass, self.swapchain_extent);
        self.pipeline_layout = layout;
        self.graphics_pipeline = pipeline;

        self.swapchain_framebuffers = Self::create_framebuffers(
            &self.device,
            &self.swapchain_image_views,
            self.render_pass,
            self.swapchain_extent,
        );

        self.command_buffers = Self::create_command_buffers(
            &self.device,
            self.command_pool,
            &self.swapchain_framebuffers,
        );

        self.images_in_flight = vec![vk::Fence::null(); self.swapchain_images.len()];
    }

    fn cleanup_swapchain(&mut self) {
        unsafe {
            for &framebuffer in &self.swapchain_framebuffers {
                self.device.destroy_framebuffer(framebuffer, None);
            }
            for &view in &self.swapchain_image_views {
                self.device.destroy_image_view(view, None);
            }
            self.device.destroy_pipeline(self.graphics_pipeline, None);
            self.device.destroy_pipeline_layout(self.pipeline_layout, None);
            self.device.destroy_render_pass(self.render_pass, None);
            self.swapchain_loader.destroy_swapchain(self.swapchain, None);
        }
    }
}

impl Drop for VulkanApp {
    fn drop(&mut self) {
        unsafe {
            self.device.device_wait_idle().unwrap();

            for &semaphore in &self.image_available_semaphores {
                self.device.destroy_semaphore(semaphore, None);
            }
            for &semaphore in &self.render_finished_semaphores {
                self.device.destroy_semaphore(semaphore, None);
            }
            for &fence in &self.in_flight_fences {
                self.device.destroy_fence(fence, None);
            }

            self.cleanup_swapchain();

            self.device.destroy_command_pool(self.command_pool, None);
            self.device.destroy_device(None);

            if let Some(ref debug_utils) = self.debug_utils_loader {
                debug_utils.destroy_debug_utils_messenger(self.debug_messenger, None);
            }
            self.surface_loader.destroy_surface(self.surface, None);
            self.instance.destroy_instance(None);
        }
    }
}

unsafe extern "system" fn vulkan_debug_callback(
    _message_severity: vk::DebugUtilsMessageSeverityFlagsEXT,
    _message_type: vk::DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: *const vk::DebugUtilsMessengerCallbackDataEXT<'_>,
    _user_data: *mut std::ffi::c_void,
) -> vk::Bool32 {
    let message = CStr::from_ptr((*p_callback_data).p_message);
    eprintln!("validation layer: {}", message.to_string_lossy());
    vk::FALSE
}

struct App {
    vulkan: Option<VulkanApp>,
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.vulkan.is_none() {
            self.vulkan = Some(VulkanApp::new(event_loop));
        }
    }

    fn window_event(
        &mut self,
        event_loop: &ActiveEventLoop,
        _window_id: WindowId,
        event: WindowEvent,
    ) {
        let vulkan = self.vulkan.as_mut().unwrap();

        match event {
            WindowEvent::CloseRequested => {
                event_loop.exit();
            }
            WindowEvent::Resized(_) => {
                vulkan.framebuffer_resized = true;
            }
            WindowEvent::RedrawRequested => {
                vulkan.draw_frame();
                vulkan.window.request_redraw();
            }
            _ => {}
        }
    }
}

fn main() {
    let event_loop = EventLoop::new().unwrap();
    event_loop.set_control_flow(ControlFlow::Poll);

    let mut app = App { vulkan: None };
    event_loop.run_app(&mut app).unwrap();
}