//! Minimal Vulkan 1.4 triangle in Rust using ash + winit
//! Shaders are compiled at runtime using shaderc

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

const WIDTH: u32 = 800;
const HEIGHT: u32 = 600;
const MAX_FRAMES_IN_FLIGHT: usize = 2;

// Vulkan 1.4 API version (ash 0.38 doesn't have API_VERSION_1_4 constant)
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

// Embedded shader sources
const VERTEX_SHADER_SOURCE: &str = r#"
#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) out vec3 fragColor;

vec2 positions[3] = vec2[](
    vec2(0.0, -0.5),
    vec2(0.5, 0.5),
    vec2(-0.5, 0.5)
);

vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}
"#;

const FRAGMENT_SHADER_SOURCE: &str = r#"
#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(location = 0) in vec3 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(fragColor, 1.0);
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
}

impl VulkanApp {
    fn new(event_loop: &ActiveEventLoop) -> Self {
        let window_attributes = Window::default_attributes()
            .with_title("Hello Vulkan 1.4 (Rust)")
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
            render_pass,
            swapchain_extent,
            graphics_pipeline,
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
        }
    }

    fn create_instance(entry: &ash::Entry, window: &Window) -> ash::Instance {
        if ENABLE_VALIDATION_LAYERS && !Self::check_validation_layer_support(entry) {
            panic!("Validation layers requested, but not available!");
        }

        let app_name = CString::new("Hello Triangle").unwrap();
        let engine_name = CString::new("No Engine").unwrap();

        let app_info = vk::ApplicationInfo::default()
            .application_name(&app_name)
            .application_version(vk::make_api_version(0, 1, 0, 0))
            .engine_name(&engine_name)
            .engine_version(vk::make_api_version(0, 1, 0, 0))
            .api_version(API_VERSION_1_4);

        let mut extensions = ash_window::enumerate_required_extensions(
            window.display_handle().unwrap().as_raw(),
        )
        .unwrap()
        .to_vec();

        if ENABLE_VALIDATION_LAYERS {
            extensions.push(debug_utils::NAME.as_ptr());
        }

        let layer_names: Vec<*const c_char> = if ENABLE_VALIDATION_LAYERS {
            VALIDATION_LAYERS.iter().map(|l| l.as_ptr()).collect()
        } else {
            vec![]
        };

        let mut create_info = vk::InstanceCreateInfo::default()
            .application_info(&app_info)
            .enabled_extension_names(&extensions)
            .enabled_layer_names(&layer_names);

        let mut debug_create_info = Self::populate_debug_messenger_create_info();
        if ENABLE_VALIDATION_LAYERS {
            create_info = create_info.push_next(&mut debug_create_info);
        }

        unsafe { entry.create_instance(&create_info, None).unwrap() }
    }

    fn check_validation_layer_support(entry: &ash::Entry) -> bool {
        let available_layers = unsafe { entry.enumerate_instance_layer_properties().unwrap() };

        for layer_name in VALIDATION_LAYERS {
            let found = available_layers.iter().any(|layer| {
                let name = unsafe { CStr::from_ptr(layer.layer_name.as_ptr()) };
                name == *layer_name
            });
            if !found {
                return false;
            }
        }
        true
    }

    fn populate_debug_messenger_create_info() -> vk::DebugUtilsMessengerCreateInfoEXT<'static> {
        vk::DebugUtilsMessengerCreateInfoEXT::default()
            .message_severity(
                vk::DebugUtilsMessageSeverityFlagsEXT::VERBOSE
                    | vk::DebugUtilsMessageSeverityFlagsEXT::WARNING
                    | vk::DebugUtilsMessageSeverityFlagsEXT::ERROR,
            )
            .message_type(
                vk::DebugUtilsMessageTypeFlagsEXT::GENERAL
                    | vk::DebugUtilsMessageTypeFlagsEXT::VALIDATION
                    | vk::DebugUtilsMessageTypeFlagsEXT::PERFORMANCE,
            )
            .pfn_user_callback(Some(vulkan_debug_callback))
    }

    fn setup_debug_messenger(
        entry: &ash::Entry,
        instance: &ash::Instance,
    ) -> (Option<debug_utils::Instance>, vk::DebugUtilsMessengerEXT) {
        let debug_utils_loader = debug_utils::Instance::new(entry, instance);
        let create_info = Self::populate_debug_messenger_create_info();
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
            .into_iter()
            .find(|&device| Self::is_device_suitable(instance, device, surface_loader, surface))
            .expect("Failed to find a suitable GPU!")
    }

    fn is_device_suitable(
        instance: &ash::Instance,
        device: vk::PhysicalDevice,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> bool {
        let indices = Self::find_queue_families(instance, device, surface_loader, surface);
        let extensions_supported = Self::check_device_extension_support(instance, device);

        let swap_chain_adequate = if extensions_supported {
            let details = Self::query_swapchain_support(device, surface_loader, surface);
            !details.formats.is_empty() && !details.present_modes.is_empty()
        } else {
            false
        };

        indices.is_complete() && extensions_supported && swap_chain_adequate
    }

    fn find_queue_families(
        instance: &ash::Instance,
        device: vk::PhysicalDevice,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> QueueFamilyIndices {
        let queue_families =
            unsafe { instance.get_physical_device_queue_family_properties(device) };

        let mut indices = QueueFamilyIndices {
            graphics_family: None,
            present_family: None,
        };

        for (i, family) in queue_families.iter().enumerate() {
            if family.queue_flags.contains(vk::QueueFlags::GRAPHICS) {
                indices.graphics_family = Some(i as u32);
            }

            let present_support = unsafe {
                surface_loader
                    .get_physical_device_surface_support(device, i as u32, surface)
                    .unwrap()
            };
            if present_support {
                indices.present_family = Some(i as u32);
            }

            if indices.is_complete() {
                break;
            }
        }

        indices
    }

    fn check_device_extension_support(instance: &ash::Instance, device: vk::PhysicalDevice) -> bool {
        let available_extensions = unsafe {
            instance
                .enumerate_device_extension_properties(device)
                .unwrap()
        };

        let required = swapchain::NAME;
        available_extensions.iter().any(|ext| {
            let name = unsafe { CStr::from_ptr(ext.extension_name.as_ptr()) };
            name == required
        })
    }

    fn query_swapchain_support(
        device: vk::PhysicalDevice,
        surface_loader: &surface::Instance,
        surface: vk::SurfaceKHR,
    ) -> SwapChainSupportDetails {
        let capabilities = unsafe {
            surface_loader
                .get_physical_device_surface_capabilities(device, surface)
                .unwrap()
        };
        let formats = unsafe {
            surface_loader
                .get_physical_device_surface_formats(device, surface)
                .unwrap()
        };
        let present_modes = unsafe {
            surface_loader
                .get_physical_device_surface_present_modes(device, surface)
                .unwrap()
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
        let indices =
            Self::find_queue_families(instance, physical_device, surface_loader, surface);

        let unique_families: Vec<u32> = {
            let mut families = vec![
                indices.graphics_family.unwrap(),
                indices.present_family.unwrap(),
            ];
            families.sort();
            families.dedup();
            families
        };

        let queue_priority = 1.0f32;
        let queue_create_infos: Vec<vk::DeviceQueueCreateInfo> = unique_families
            .iter()
            .map(|&family| {
                vk::DeviceQueueCreateInfo::default()
                    .queue_family_index(family)
                    .queue_priorities(std::slice::from_ref(&queue_priority))
            })
            .collect();

        let device_features = vk::PhysicalDeviceFeatures::default();

        let extension_names = [swapchain::NAME.as_ptr()];

        #[allow(deprecated)]
        let layer_names: Vec<*const c_char> = if ENABLE_VALIDATION_LAYERS {
            VALIDATION_LAYERS.iter().map(|l| l.as_ptr()).collect()
        } else {
            vec![]
        };

        #[allow(deprecated)]
        let create_info = vk::DeviceCreateInfo::default()
            .queue_create_infos(&queue_create_infos)
            .enabled_features(&device_features)
            .enabled_extension_names(&extension_names)
            .enabled_layer_names(&layer_names);

        let device = unsafe {
            instance
                .create_device(physical_device, &create_info, None)
                .unwrap()
        };

        let graphics_queue =
            unsafe { device.get_device_queue(indices.graphics_family.unwrap(), 0) };
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
        let details = Self::query_swapchain_support(physical_device, surface_loader, surface);

        let surface_format = Self::choose_swap_surface_format(&details.formats);
        let present_mode = Self::choose_swap_present_mode(&details.present_modes);
        let extent = Self::choose_swap_extent(&details.capabilities, window);

        let mut image_count = details.capabilities.min_image_count + 1;
        if details.capabilities.max_image_count > 0
            && image_count > details.capabilities.max_image_count
        {
            image_count = details.capabilities.max_image_count;
        }

        let indices =
            Self::find_queue_families(instance, physical_device, surface_loader, surface);
        let queue_family_indices = [
            indices.graphics_family.unwrap(),
            indices.present_family.unwrap(),
        ];

        let (sharing_mode, queue_family_index_count, p_queue_family_indices) =
            if indices.graphics_family != indices.present_family {
                (
                    vk::SharingMode::CONCURRENT,
                    2,
                    queue_family_indices.as_ptr(),
                )
            } else {
                (vk::SharingMode::EXCLUSIVE, 0, std::ptr::null())
            };

        let create_info = vk::SwapchainCreateInfoKHR {
            s_type: vk::StructureType::SWAPCHAIN_CREATE_INFO_KHR,
            surface,
            min_image_count: image_count,
            image_format: surface_format.format,
            image_color_space: surface_format.color_space,
            image_extent: extent,
            image_array_layers: 1,
            image_usage: vk::ImageUsageFlags::COLOR_ATTACHMENT,
            image_sharing_mode: sharing_mode,
            queue_family_index_count,
            p_queue_family_indices,
            pre_transform: details.capabilities.current_transform,
            composite_alpha: vk::CompositeAlphaFlagsKHR::OPAQUE,
            present_mode,
            clipped: vk::TRUE,
            old_swapchain: vk::SwapchainKHR::null(),
            ..Default::default()
        };

        let swapchain = unsafe { swapchain_loader.create_swapchain(&create_info, None).unwrap() };
        let images = unsafe { swapchain_loader.get_swapchain_images(swapchain).unwrap() };

        (swapchain, images, surface_format.format, extent)
    }

    fn choose_swap_surface_format(formats: &[vk::SurfaceFormatKHR]) -> vk::SurfaceFormatKHR {
        formats
            .iter()
            .find(|f| {
                f.format == vk::Format::B8G8R8A8_SRGB
                    && f.color_space == vk::ColorSpaceKHR::SRGB_NONLINEAR
            })
            .cloned()
            .unwrap_or(formats[0])
    }

    fn choose_swap_present_mode(present_modes: &[vk::PresentModeKHR]) -> vk::PresentModeKHR {
        present_modes
            .iter()
            .find(|&&mode| mode == vk::PresentModeKHR::MAILBOX)
            .cloned()
            .unwrap_or(vk::PresentModeKHR::FIFO)
    }

    fn choose_swap_extent(
        capabilities: &vk::SurfaceCapabilitiesKHR,
        window: &Window,
    ) -> vk::Extent2D {
        if capabilities.current_extent.width != u32::MAX {
            capabilities.current_extent
        } else {
            let size = window.inner_size();
            vk::Extent2D {
                width: size.width.clamp(
                    capabilities.min_image_extent.width,
                    capabilities.max_image_extent.width,
                ),
                height: size.height.clamp(
                    capabilities.min_image_extent.height,
                    capabilities.max_image_extent.height,
                ),
            }
        }
    }

    fn create_image_views(
        device: &ash::Device,
        images: &[vk::Image],
        format: vk::Format,
    ) -> Vec<vk::ImageView> {
        images
            .iter()
            .map(|&image| {
                let create_info = vk::ImageViewCreateInfo::default()
                    .image(image)
                    .view_type(vk::ImageViewType::TYPE_2D)
                    .format(format)
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

    fn create_render_pass(device: &ash::Device, format: vk::Format) -> vk::RenderPass {
        let color_attachment = vk::AttachmentDescription::default()
            .format(format)
            .samples(vk::SampleCountFlags::TYPE_1)
            .load_op(vk::AttachmentLoadOp::CLEAR)
            .store_op(vk::AttachmentStoreOp::STORE)
            .stencil_load_op(vk::AttachmentLoadOp::DONT_CARE)
            .stencil_store_op(vk::AttachmentStoreOp::DONT_CARE)
            .initial_layout(vk::ImageLayout::UNDEFINED)
            .final_layout(vk::ImageLayout::PRESENT_SRC_KHR);

        let color_attachment_ref = vk::AttachmentReference {
            attachment: 0,
            layout: vk::ImageLayout::COLOR_ATTACHMENT_OPTIMAL,
        };

        let subpass = vk::SubpassDescription::default()
            .pipeline_bind_point(vk::PipelineBindPoint::GRAPHICS)
            .color_attachments(std::slice::from_ref(&color_attachment_ref));

        let dependency = vk::SubpassDependency::default()
            .src_subpass(vk::SUBPASS_EXTERNAL)
            .dst_subpass(0)
            .src_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .src_access_mask(vk::AccessFlags::empty())
            .dst_stage_mask(vk::PipelineStageFlags::COLOR_ATTACHMENT_OUTPUT)
            .dst_access_mask(vk::AccessFlags::COLOR_ATTACHMENT_WRITE);

        let attachments = [color_attachment];
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
        // Compile shaders at runtime
        let compiler = shaderc::Compiler::new().expect("Failed to create shader compiler");

        let vert_spirv = compile_shader(
            &compiler,
            VERTEX_SHADER_SOURCE,
            shaderc::ShaderKind::Vertex,
            "hello.vert",
        );
        let frag_spirv = compile_shader(
            &compiler,
            FRAGMENT_SHADER_SOURCE,
            shaderc::ShaderKind::Fragment,
            "hello.frag",
        );

        let vert_module = Self::create_shader_module(device, &vert_spirv);
        let frag_module = Self::create_shader_module(device, &frag_spirv);

        let entry_point = CString::new("main").unwrap();

        let vert_stage = vk::PipelineShaderStageCreateInfo::default()
            .stage(vk::ShaderStageFlags::VERTEX)
            .module(vert_module)
            .name(&entry_point);

        let frag_stage = vk::PipelineShaderStageCreateInfo::default()
            .stage(vk::ShaderStageFlags::FRAGMENT)
            .module(frag_module)
            .name(&entry_point);

        let shader_stages = [vert_stage, frag_stage];

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

        let pipeline_layout_info = vk::PipelineLayoutCreateInfo::default();
        let pipeline_layout = unsafe {
            device
                .create_pipeline_layout(&pipeline_layout_info, None)
                .unwrap()
        };

        let pipeline_info = vk::GraphicsPipelineCreateInfo::default()
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

        let pipelines = unsafe {
            device
                .create_graphics_pipelines(vk::PipelineCache::null(), &[pipeline_info], None)
                .unwrap()
        };

        unsafe {
            device.destroy_shader_module(vert_module, None);
            device.destroy_shader_module(frag_module, None);
        }

        (pipeline_layout, pipelines[0])
    }

    fn create_shader_module(device: &ash::Device, code: &[u32]) -> vk::ShaderModule {
        let create_info = vk::ShaderModuleCreateInfo::default().code(code);
        unsafe { device.create_shader_module(&create_info, None).unwrap() }
    }

    fn create_framebuffers(
        device: &ash::Device,
        image_views: &[vk::ImageView],
        render_pass: vk::RenderPass,
        extent: vk::Extent2D,
    ) -> Vec<vk::Framebuffer> {
        image_views
            .iter()
            .map(|&view| {
                let attachments = [view];
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
        let indices =
            Self::find_queue_families(instance, physical_device, surface_loader, surface);

        let pool_info = vk::CommandPoolCreateInfo::default()
            .queue_family_index(indices.graphics_family.unwrap());

        unsafe { device.create_command_pool(&pool_info, None).unwrap() }
    }

    fn create_command_buffers(
        device: &ash::Device,
        command_pool: vk::CommandPool,
        framebuffers: &[vk::Framebuffer],
        render_pass: vk::RenderPass,
        extent: vk::Extent2D,
        pipeline: vk::Pipeline,
    ) -> Vec<vk::CommandBuffer> {
        let alloc_info = vk::CommandBufferAllocateInfo::default()
            .command_pool(command_pool)
            .level(vk::CommandBufferLevel::PRIMARY)
            .command_buffer_count(framebuffers.len() as u32);

        let command_buffers = unsafe { device.allocate_command_buffers(&alloc_info).unwrap() };

        for (i, &cmd_buffer) in command_buffers.iter().enumerate() {
            let begin_info = vk::CommandBufferBeginInfo::default();
            unsafe { device.begin_command_buffer(cmd_buffer, &begin_info).unwrap() };

            let clear_value = vk::ClearValue {
                color: vk::ClearColorValue {
                    float32: [0.0, 0.0, 0.0, 1.0],
                },
            };

            let render_pass_info = vk::RenderPassBeginInfo::default()
                .render_pass(render_pass)
                .framebuffer(framebuffers[i])
                .render_area(vk::Rect2D {
                    offset: vk::Offset2D { x: 0, y: 0 },
                    extent,
                })
                .clear_values(std::slice::from_ref(&clear_value));

            unsafe {
                device.cmd_begin_render_pass(cmd_buffer, &render_pass_info, vk::SubpassContents::INLINE);
                device.cmd_bind_pipeline(cmd_buffer, vk::PipelineBindPoint::GRAPHICS, pipeline);
                device.cmd_draw(cmd_buffer, 3, 1, 0, 0);
                device.cmd_end_render_pass(cmd_buffer);
                device.end_command_buffer(cmd_buffer).unwrap();
            }
        }

        command_buffers
    }

    fn create_sync_objects(
        device: &ash::Device,
    ) -> (Vec<vk::Semaphore>, Vec<vk::Semaphore>, Vec<vk::Fence>) {
        let semaphore_info = vk::SemaphoreCreateInfo::default();
        let fence_info = vk::FenceCreateInfo::default().flags(vk::FenceCreateFlags::SIGNALED);

        let mut image_available = Vec::with_capacity(MAX_FRAMES_IN_FLIGHT);
        let mut render_finished = Vec::with_capacity(MAX_FRAMES_IN_FLIGHT);
        let mut in_flight = Vec::with_capacity(MAX_FRAMES_IN_FLIGHT);

        for _ in 0..MAX_FRAMES_IN_FLIGHT {
            unsafe {
                image_available.push(device.create_semaphore(&semaphore_info, None).unwrap());
                render_finished.push(device.create_semaphore(&semaphore_info, None).unwrap());
                in_flight.push(device.create_fence(&fence_info, None).unwrap());
            }
        }

        (image_available, render_finished, in_flight)
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
            self.render_pass,
            self.swapchain_extent,
            self.graphics_pipeline,
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
