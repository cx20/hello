// DirectX 12 Harmonograph with Compute Shader
// forked from https://github.com/microsoft/windows-rs/tree/master/crates/samples/windows/direct3d12

use windows::{
    core::*, Win32::Foundation::*, Win32::Graphics::Direct3D::Fxc::*, Win32::Graphics::Direct3D::*,
    Win32::Graphics::Direct3D12::*, Win32::Graphics::Dxgi::Common::*, Win32::Graphics::Dxgi::*,
    Win32::System::LibraryLoader::*, Win32::System::Threading::*,
    Win32::UI::WindowsAndMessaging::*,
};

// Debug output helper function (prints to console)
fn debug_output(msg: &str) {
    print!("{}", msg);
}

// Number of vertices for harmonograph
const VERTEX_COUNT: u32 = 500000;
const THREAD_GROUP_SIZE: u32 = 64;

trait DXSample {
    fn new(command_line: &SampleCommandLine) -> Result<Self>
    where
        Self: Sized;

    fn bind_to_window(&mut self, hwnd: &HWND) -> Result<()>;

    fn update(&mut self) {}
    fn render(&mut self) {}
    fn on_key_up(&mut self, _key: u8) {}
    fn on_key_down(&mut self, _key: u8) {}

    fn title(&self) -> String {
        "DXSample".into()
    }

    fn window_size(&self) -> (i32, i32) {
        (640, 480)
    }
}

#[derive(Clone)]
struct SampleCommandLine {
    use_warp_device: bool,
}

fn build_command_line() -> SampleCommandLine {
    let mut use_warp_device = false;

    for arg in std::env::args() {
        if arg.eq_ignore_ascii_case("-warp") || arg.eq_ignore_ascii_case("/warp") {
            use_warp_device = true;
        }
    }

    SampleCommandLine { use_warp_device }
}

fn run_sample<S>() -> Result<()>
where
    S: DXSample,
{
    let instance = unsafe { GetModuleHandleA(None)? };

    let wc = WNDCLASSEXA {
        cbSize: std::mem::size_of::<WNDCLASSEXA>() as u32,
        style: CS_HREDRAW | CS_VREDRAW,
        lpfnWndProc: Some(wndproc::<S>),
        hInstance: instance.into(),
        hCursor: unsafe { LoadCursorW(None, IDC_ARROW)? },
        lpszClassName: s!("RustWindowClass"),
        ..Default::default()
    };

    let command_line = build_command_line();
    let mut sample = S::new(&command_line)?;

    let size = sample.window_size();

    let atom = unsafe { RegisterClassExA(&wc) };
    debug_assert_ne!(atom, 0);

    let mut window_rect = RECT {
        left: 0,
        top: 0,
        right: size.0,
        bottom: size.1,
    };
    unsafe { AdjustWindowRect(&mut window_rect, WS_OVERLAPPEDWINDOW, false)? };

    let mut title = sample.title();

    if command_line.use_warp_device {
        title.push_str(" (WARP)");
    }

    title.push('\0');

    let hwnd = unsafe {
        let sample_ptr = &mut sample as *mut _ as _;
        CreateWindowExA(
            WINDOW_EX_STYLE::default(),
            s!("RustWindowClass"),
            PCSTR(title.as_ptr()),
            WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            size.0,
            size.1,
            None,
            None,
            Some(instance.into()),
            Some(sample_ptr),
        )
    }?;

    sample.bind_to_window(&hwnd)?;
    unsafe {
        _ = ShowWindow(hwnd, SW_SHOW);
    };

    loop {
        let mut message = MSG::default();

        if unsafe { PeekMessageA(&mut message, None, 0, 0, PM_REMOVE) }.into() {
            unsafe {
                _ = TranslateMessage(&message);
                DispatchMessageA(&message);
            }

            if message.message == WM_QUIT {
                break;
            }
        }
    }

    Ok(())
}

fn sample_wndproc<S: DXSample>(sample: &mut S, message: u32, wparam: WPARAM) -> bool {
    match message {
        WM_KEYDOWN => {
            sample.on_key_down(wparam.0 as u8);
            true
        }
        WM_KEYUP => {
            sample.on_key_up(wparam.0 as u8);
            true
        }
        WM_PAINT => {
            sample.update();
            sample.render();
            true
        }
        _ => false,
    }
}

extern "system" fn wndproc<S: DXSample>(
    window: HWND,
    message: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    match message {
        WM_CREATE => {
            unsafe {
                let create_struct: &CREATESTRUCTA = &*(lparam.0 as *const CREATESTRUCTA);
                SetWindowLongPtrA(window, GWLP_USERDATA, create_struct.lpCreateParams as _);
            }
            return LRESULT::default();
        }
        WM_DESTROY => {
            unsafe { PostQuitMessage(0) };
            return LRESULT::default();
        }
        _ => {
            let user_data = unsafe { GetWindowLongPtrA(window, GWLP_USERDATA) };
            let sample = std::ptr::NonNull::<S>::new(user_data as _);
            if let Some(mut s) = sample {
                if sample_wndproc(unsafe { s.as_mut() }, message, wparam) {
                    return LRESULT::default();
                }
            }
        }
    }
    unsafe { DefWindowProcA(window, message, wparam, lparam) }
}

fn get_hardware_adapter(factory: &IDXGIFactory4) -> Result<IDXGIAdapter1> {
    for i in 0.. {
        let adapter = unsafe { factory.EnumAdapters1(i)? };
        let desc = unsafe { adapter.GetDesc1()? };

        if (DXGI_ADAPTER_FLAG(desc.Flags as _) & DXGI_ADAPTER_FLAG_SOFTWARE)
            != DXGI_ADAPTER_FLAG_NONE
        {
            continue;
        }

        if unsafe {
            D3D12CreateDevice(
                &adapter,
                D3D_FEATURE_LEVEL_11_0,
                std::ptr::null_mut::<Option<ID3D12Device>>(),
            )
        }
        .is_ok()
        {
            return Ok(adapter);
        }
    }

    unreachable!()
}

mod d3d12_harmonograph {
    use super::*;

    const FRAME_COUNT: u32 = 2;

    // Harmonograph parameters constant buffer structure
    // Must match HLSL cbuffer layout
    #[repr(C)]
    #[derive(Clone, Copy)]
    struct HarmonographParams {
        a1: f32, f1: f32, p1: f32, d1: f32,
        a2: f32, f2: f32, p2: f32, d2: f32,
        a3: f32, f3: f32, p3: f32, d3: f32,
        a4: f32, f4: f32, p4: f32, d4: f32,
        max_num: u32,
        padding: [f32; 3],
        resolution: [f32; 2],
        padding2: [f32; 2],
    }

    pub struct Sample {
        dxgi_factory: IDXGIFactory4,
        device: ID3D12Device,
        resources: Option<Resources>,
    }

    struct Resources {
        // Command queue and swap chain
        command_queue: ID3D12CommandQueue,
        swap_chain: IDXGISwapChain3,
        frame_index: u32,
        render_targets: [ID3D12Resource; FRAME_COUNT as usize],
        rtv_heap: ID3D12DescriptorHeap,
        rtv_descriptor_size: usize,
        viewport: D3D12_VIEWPORT,
        scissor_rect: RECT,

        // Compute shader resources
        compute_command_allocator: ID3D12CommandAllocator,
        compute_root_signature: ID3D12RootSignature,
        compute_pso: ID3D12PipelineState,
        compute_command_list: ID3D12GraphicsCommandList,

        // Graphics shader resources
        graphics_command_allocator: ID3D12CommandAllocator,
        graphics_root_signature: ID3D12RootSignature,
        graphics_pso: ID3D12PipelineState,
        graphics_command_list: ID3D12GraphicsCommandList,

        // Structured buffers for compute shader output
        position_buffer: ID3D12Resource,
        color_buffer: ID3D12Resource,

        // Constant buffer for harmonograph parameters
        constant_buffer: ID3D12Resource,

        // Descriptor heaps
        cbv_srv_uav_heap: ID3D12DescriptorHeap,
        cbv_srv_uav_descriptor_size: usize,

        // Synchronization
        fence: ID3D12Fence,
        fence_value: u64,
        fence_event: HANDLE,

        // Window size
        width: u32,
        height: u32,
        
        // Frame counter for debug
        frame_count: u64,

        // Harmonograph parameters and RNG state
        harmonograph_params: HarmonographParams,
        rng_state: u32,
    }

    impl DXSample for Sample {
        fn new(command_line: &SampleCommandLine) -> Result<Self> {
            debug_output("[Sample::new] Creating device\n");
            let (dxgi_factory, device) = create_device(command_line)?;
            debug_output("[Sample::new] Device created successfully\n");

            Ok(Sample {
                dxgi_factory,
                device,
                resources: None,
            })
        }

        fn bind_to_window(&mut self, hwnd: &HWND) -> Result<()> {
            debug_output("[bind_to_window] Starting initialization\n");
            
            let command_queue: ID3D12CommandQueue = unsafe {
                self.device.CreateCommandQueue(&D3D12_COMMAND_QUEUE_DESC {
                    Type: D3D12_COMMAND_LIST_TYPE_DIRECT,
                    ..Default::default()
                })?
            };
            debug_output("[bind_to_window] Command queue created\n");

            let (width, height) = self.window_size();
            let width = width as u32;
            let height = height as u32;
            debug_output(&format!("[bind_to_window] Window size: {}x{}\n", width, height));

            let swap_chain_desc = DXGI_SWAP_CHAIN_DESC1 {
                BufferCount: FRAME_COUNT,
                Width: width,
                Height: height,
                Format: DXGI_FORMAT_R8G8B8A8_UNORM,
                BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
                SwapEffect: DXGI_SWAP_EFFECT_FLIP_DISCARD,
                SampleDesc: DXGI_SAMPLE_DESC {
                    Count: 1,
                    ..Default::default()
                },
                ..Default::default()
            };

            let swap_chain: IDXGISwapChain3 = unsafe {
                self.dxgi_factory.CreateSwapChainForHwnd(
                    &command_queue,
                    *hwnd,
                    &swap_chain_desc,
                    None,
                    None,
                )?
            }
            .cast()?;
            debug_output("[bind_to_window] Swap chain created\n");

            unsafe {
                self.dxgi_factory
                    .MakeWindowAssociation(*hwnd, DXGI_MWA_NO_ALT_ENTER)?;
            }

            let frame_index = unsafe { swap_chain.GetCurrentBackBufferIndex() };
            debug_output(&format!("[bind_to_window] Initial frame index: {}\n", frame_index));

            // Create RTV heap
            let rtv_heap: ID3D12DescriptorHeap = unsafe {
                self.device
                    .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
                        NumDescriptors: FRAME_COUNT,
                        Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
                        ..Default::default()
                    })
            }?;
            debug_output("[bind_to_window] RTV heap created\n");

            let rtv_descriptor_size = unsafe {
                self.device
                    .GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV)
            } as usize;
            let rtv_handle = unsafe { rtv_heap.GetCPUDescriptorHandleForHeapStart() };

            let render_targets: [ID3D12Resource; FRAME_COUNT as usize] =
                array_init::try_array_init(|i: usize| -> Result<ID3D12Resource> {
                    let render_target: ID3D12Resource = unsafe { swap_chain.GetBuffer(i as u32) }?;
                    unsafe {
                        self.device.CreateRenderTargetView(
                            &render_target,
                            None,
                            D3D12_CPU_DESCRIPTOR_HANDLE {
                                ptr: rtv_handle.ptr + i * rtv_descriptor_size,
                            },
                        )
                    };
                    Ok(render_target)
                })?;
            debug_output("[bind_to_window] Render targets created\n");

            let viewport = D3D12_VIEWPORT {
                TopLeftX: 0.0,
                TopLeftY: 0.0,
                Width: width as f32,
                Height: height as f32,
                MinDepth: D3D12_MIN_DEPTH,
                MaxDepth: D3D12_MAX_DEPTH,
            };

            let scissor_rect = RECT {
                left: 0,
                top: 0,
                right: width as i32,
                bottom: height as i32,
            };

            // Create CBV/SRV/UAV descriptor heap
            // Layout: [CBV] [Position UAV] [Color UAV] [Position SRV] [Color SRV]
            let cbv_srv_uav_heap: ID3D12DescriptorHeap = unsafe {
                self.device
                    .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
                        NumDescriptors: 5,
                        Type: D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,
                        Flags: D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
                        ..Default::default()
                    })
            }?;
            
            let cbv_srv_uav_descriptor_size = unsafe {
                self.device
                    .GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV)
            } as usize;
            debug_output(&format!("[bind_to_window] CBV/SRV/UAV heap created, descriptor size: {}\n", cbv_srv_uav_descriptor_size));

            // Create constant buffer
            let harmonograph_params = initial_harmonograph_params(width, height);
            let constant_buffer = create_constant_buffer(&self.device, &harmonograph_params)?;
            debug_output("[bind_to_window] Constant buffer created\n");

            // Create structured buffers for position and color
            let (position_buffer, color_buffer) =
                create_structured_buffers(&self.device)?;
            debug_output("[bind_to_window] Structured buffers created\n");

            // Create descriptors
            create_buffer_views(
                &self.device,
                &cbv_srv_uav_heap,
                &constant_buffer,
                &position_buffer,
                &color_buffer,
            )?;
            debug_output("[bind_to_window] Buffer views created\n");

            // Create compute resources
            let compute_command_allocator = unsafe {
                self.device
                    .CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT)
            }?;
            debug_output("[bind_to_window] Compute command allocator created\n");

            let compute_root_signature = create_compute_root_signature(&self.device)?;
            debug_output("[bind_to_window] Compute root signature created\n");
            
            let compute_pso =
                create_compute_pipeline_state(&self.device, &compute_root_signature)?;
            debug_output("[bind_to_window] Compute PSO created\n");

            let compute_command_list: ID3D12GraphicsCommandList = unsafe {
                self.device.CreateCommandList(
                    0,
                    D3D12_COMMAND_LIST_TYPE_DIRECT,
                    &compute_command_allocator,
                    &compute_pso,
                )
            }?;
            unsafe { compute_command_list.Close()? };
            debug_output("[bind_to_window] Compute command list created\n");

            // Create graphics resources
            let graphics_command_allocator = unsafe {
                self.device
                    .CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT)
            }?;
            debug_output("[bind_to_window] Graphics command allocator created\n");

            let graphics_root_signature = create_graphics_root_signature(&self.device)?;
            debug_output("[bind_to_window] Graphics root signature created\n");
            
            let graphics_pso =
                create_graphics_pipeline_state(&self.device, &graphics_root_signature)?;
            debug_output("[bind_to_window] Graphics PSO created\n");

            let graphics_command_list: ID3D12GraphicsCommandList = unsafe {
                self.device.CreateCommandList(
                    0,
                    D3D12_COMMAND_LIST_TYPE_DIRECT,
                    &graphics_command_allocator,
                    &graphics_pso,
                )
            }?;
            unsafe { graphics_command_list.Close()? };
            debug_output("[bind_to_window] Graphics command list created\n");

            // Create fence
            let fence = unsafe { self.device.CreateFence(0, D3D12_FENCE_FLAG_NONE) }?;
            let fence_value = 1;
            let fence_event = unsafe { CreateEventA(None, false, false, None)? };
            debug_output("[bind_to_window] Fence created\n");

            self.resources = Some(Resources {
                command_queue,
                swap_chain,
                frame_index,
                render_targets,
                rtv_heap,
                rtv_descriptor_size,
                viewport,
                scissor_rect,
                compute_command_allocator,
                compute_root_signature,
                compute_pso,
                compute_command_list,
                graphics_command_allocator,
                graphics_root_signature,
                graphics_pso,
                graphics_command_list,
                position_buffer,
                color_buffer,
                constant_buffer,
                cbv_srv_uav_heap,
                cbv_srv_uav_descriptor_size,
                fence,
                fence_value,
                fence_event,
                width,
                height,
                frame_count: 0,
                harmonograph_params,
                rng_state: 0x1234_5678,
            });
            debug_output("[bind_to_window] Resources stored\n");

            // Execute compute shader once to generate vertex data
            debug_output("[bind_to_window] Calling execute_compute_shader\n");
            self.execute_compute_shader()?;
            debug_output("[bind_to_window] Compute shader executed\n");

            debug_output("[bind_to_window] Initialization complete\n");
            Ok(())
        }

        fn title(&self) -> String {
            "DirectX 12 Harmonograph (Compute Shader)".into()
        }

        fn window_size(&self) -> (i32, i32) {
            (800, 600)
        }

        fn render(&mut self) {
            if let Err(err) = self.execute_compute_shader() {
                debug_output(&format!("[render] Compute failed: {:?}\n", err));
            }

            if let Some(resources) = &mut self.resources {
                resources.frame_count += 1;

                // Only log every 60 frames to avoid flooding DebugView
                if resources.frame_count % 60 == 1 {
                    debug_output(&format!("[render] Frame {}, frame_index={}\n",
                        resources.frame_count, resources.frame_index));
                }

                populate_graphics_command_list(resources).unwrap();

                let command_list = Some(resources.graphics_command_list.cast().unwrap());
                unsafe { resources.command_queue.ExecuteCommandLists(&[command_list]) };

                unsafe { resources.swap_chain.Present(1, DXGI_PRESENT(0)) }
                    .ok()
                    .unwrap();

                wait_for_previous_frame(resources);
            }
        }
    }

    impl Sample {
        fn execute_compute_shader(&mut self) -> Result<()> {
            debug_output("[execute_compute_shader] Starting\n");
            
            if let Some(resources) = &mut self.resources {
                update_harmonograph_params(resources);
                write_constant_buffer(resources)?;

                debug_output("[execute_compute_shader] Resetting command allocator\n");
                unsafe {
                    resources.compute_command_allocator.Reset()?;
                    resources.compute_command_list.Reset(
                        &resources.compute_command_allocator,
                        &resources.compute_pso,
                    )?;
                }
                debug_output("[execute_compute_shader] Command list reset\n");

                let command_list = &resources.compute_command_list;

                unsafe {
                    command_list.SetComputeRootSignature(&resources.compute_root_signature);
                    command_list.SetDescriptorHeaps(&[Some(resources.cbv_srv_uav_heap.clone())]);

                    let heap_start = resources
                        .cbv_srv_uav_heap
                        .GetGPUDescriptorHandleForHeapStart();

                    // Set CBV (index 0)
                    command_list.SetComputeRootDescriptorTable(0, heap_start);

                    // Set UAVs (index 1 and 2)
                    let descriptor_size = resources.cbv_srv_uav_descriptor_size as u64;

                    command_list.SetComputeRootDescriptorTable(
                        1,
                        D3D12_GPU_DESCRIPTOR_HANDLE {
                            ptr: heap_start.ptr + descriptor_size,
                        },
                    );
                    command_list.SetComputeRootDescriptorTable(
                        2,
                        D3D12_GPU_DESCRIPTOR_HANDLE {
                            ptr: heap_start.ptr + descriptor_size * 2,
                        },
                    );

                    // Dispatch compute shader
                    let thread_groups = (VERTEX_COUNT + THREAD_GROUP_SIZE - 1) / THREAD_GROUP_SIZE;
                    debug_output(&format!("[execute_compute_shader] Dispatching {} thread groups\n", thread_groups));
                    command_list.Dispatch(thread_groups, 1, 1);

                    // UAV barrier to ensure compute shader completes before graphics
                    let uav_barrier = D3D12_RESOURCE_BARRIER {
                        Type: D3D12_RESOURCE_BARRIER_TYPE_UAV,
                        Flags: D3D12_RESOURCE_BARRIER_FLAG_NONE,
                        Anonymous: D3D12_RESOURCE_BARRIER_0 {
                            UAV: std::mem::ManuallyDrop::new(D3D12_RESOURCE_UAV_BARRIER {
                                pResource: std::mem::transmute_copy(&resources.position_buffer),
                            }),
                        },
                    };
                    command_list.ResourceBarrier(&[uav_barrier]);

                    let color_uav_barrier = D3D12_RESOURCE_BARRIER {
                        Type: D3D12_RESOURCE_BARRIER_TYPE_UAV,
                        Flags: D3D12_RESOURCE_BARRIER_FLAG_NONE,
                        Anonymous: D3D12_RESOURCE_BARRIER_0 {
                            UAV: std::mem::ManuallyDrop::new(D3D12_RESOURCE_UAV_BARRIER {
                                pResource: std::mem::transmute_copy(&resources.color_buffer),
                            }),
                        },
                    };
                    command_list.ResourceBarrier(&[color_uav_barrier]);

                    command_list.Close()?;
                }
                debug_output("[execute_compute_shader] Command list closed\n");

                let command_list = Some(resources.compute_command_list.cast().unwrap());
                unsafe { resources.command_queue.ExecuteCommandLists(&[command_list]) };
                debug_output("[execute_compute_shader] Command list executed\n");

                // Wait for compute to complete
                wait_for_previous_frame(resources);
                debug_output("[execute_compute_shader] Wait complete\n");
            }

            debug_output("[execute_compute_shader] Done\n");
            Ok(())
        }
    }

    fn populate_graphics_command_list(resources: &Resources) -> Result<()> {
        // Only log first few frames
        let should_log = resources.frame_count <= 5;
        
        if should_log {
            debug_output(&format!("[populate_graphics_command_list] Frame {}\n", resources.frame_count));
        }
        
        unsafe {
            resources.graphics_command_allocator.Reset()?;
            resources.graphics_command_list.Reset(
                &resources.graphics_command_allocator,
                &resources.graphics_pso,
            )?;
        }

        let command_list = &resources.graphics_command_list;

        unsafe {
            command_list.SetGraphicsRootSignature(&resources.graphics_root_signature);
            command_list.SetDescriptorHeaps(&[Some(resources.cbv_srv_uav_heap.clone())]);

            let heap_start = resources
                .cbv_srv_uav_heap
                .GetGPUDescriptorHandleForHeapStart();

            // Root param 0: CBV at heap index 0
            command_list.SetGraphicsRootDescriptorTable(0, heap_start);
            
            // Root param 1: SRVs at heap index 3 (position SRV and color SRV are contiguous)
            let srv_handle = D3D12_GPU_DESCRIPTOR_HANDLE {
                ptr: heap_start.ptr + (3 * resources.cbv_srv_uav_descriptor_size) as u64,
            };
            command_list.SetGraphicsRootDescriptorTable(1, srv_handle);
            
            if should_log {
                debug_output(&format!("[populate_graphics_command_list] CBV at heap offset 0, SRV at offset {}\n", 
                    3 * resources.cbv_srv_uav_descriptor_size));
            }

            command_list.RSSetViewports(&[resources.viewport]);
            command_list.RSSetScissorRects(&[resources.scissor_rect]);
        }

        // Transition to render target
        let barrier = transition_barrier(
            &resources.render_targets[resources.frame_index as usize],
            D3D12_RESOURCE_STATE_PRESENT,
            D3D12_RESOURCE_STATE_RENDER_TARGET,
        );
        unsafe { command_list.ResourceBarrier(&[barrier]) };

        let rtv_handle = D3D12_CPU_DESCRIPTOR_HANDLE {
            ptr: unsafe { resources.rtv_heap.GetCPUDescriptorHandleForHeapStart() }.ptr
                + resources.frame_index as usize * resources.rtv_descriptor_size,
        };

        unsafe {
            command_list.OMSetRenderTargets(1, Some(&rtv_handle), false, None);

            // Clear to dark background
            command_list.ClearRenderTargetView(
                rtv_handle,
                &[0.0_f32, 0.0_f32, 0.1_f32, 1.0_f32],
                None,
            );

            // Draw harmonograph as line strip
            command_list.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_LINESTRIP);
            
            if should_log {
                debug_output(&format!("[populate_graphics_command_list] Drawing {} vertices\n", VERTEX_COUNT));
            }
            
            command_list.DrawInstanced(VERTEX_COUNT, 1, 0, 0);

            // Transition back to present
            command_list.ResourceBarrier(&[transition_barrier(
                &resources.render_targets[resources.frame_index as usize],
                D3D12_RESOURCE_STATE_RENDER_TARGET,
                D3D12_RESOURCE_STATE_PRESENT,
            )]);
        }

        if should_log {
            debug_output("[populate_graphics_command_list] Command list closed\n");
        }
        
        unsafe { command_list.Close() }
    }

    fn transition_barrier(
        resource: &ID3D12Resource,
        state_before: D3D12_RESOURCE_STATES,
        state_after: D3D12_RESOURCE_STATES,
    ) -> D3D12_RESOURCE_BARRIER {
        D3D12_RESOURCE_BARRIER {
            Type: D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
            Flags: D3D12_RESOURCE_BARRIER_FLAG_NONE,
            Anonymous: D3D12_RESOURCE_BARRIER_0 {
                Transition: std::mem::ManuallyDrop::new(D3D12_RESOURCE_TRANSITION_BARRIER {
                    pResource: unsafe { std::mem::transmute_copy(resource) },
                    StateBefore: state_before,
                    StateAfter: state_after,
                    Subresource: D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                }),
            },
        }
    }

    fn create_device(command_line: &SampleCommandLine) -> Result<(IDXGIFactory4, ID3D12Device)> {
        debug_output("[create_device] Starting device creation\n");
        
        if cfg!(debug_assertions) {
            unsafe {
                let mut debug: Option<ID3D12Debug> = None;
                if let Some(debug) = D3D12GetDebugInterface(&mut debug).ok().and(debug) {
                    debug.EnableDebugLayer();
                    debug_output("[create_device] Debug layer enabled\n");
                }
            }
        }

        let dxgi_factory_flags = if cfg!(debug_assertions) {
            DXGI_CREATE_FACTORY_DEBUG
        } else {
            DXGI_CREATE_FACTORY_FLAGS(0)
        };

        let dxgi_factory: IDXGIFactory4 = unsafe { CreateDXGIFactory2(dxgi_factory_flags) }?;
        debug_output("[create_device] DXGI factory created\n");

        let adapter = if command_line.use_warp_device {
            debug_output("[create_device] Using WARP adapter\n");
            unsafe { dxgi_factory.EnumWarpAdapter() }
        } else {
            debug_output("[create_device] Getting hardware adapter\n");
            get_hardware_adapter(&dxgi_factory)
        }?;

        let mut device: Option<ID3D12Device> = None;
        unsafe { D3D12CreateDevice(&adapter, D3D_FEATURE_LEVEL_11_0, &mut device) }?;
        debug_output("[create_device] D3D12 device created\n");
        
        Ok((dxgi_factory, device.unwrap()))
    }

    fn initial_harmonograph_params(width: u32, height: u32) -> HarmonographParams {
        HarmonographParams {
            a1: 50.0, f1: 2.0, p1: 1.0 / 16.0, d1: 0.02,
            a2: 50.0, f2: 2.0, p2: 3.0 / 2.0, d2: 0.0315,
            a3: 50.0, f3: 2.0, p3: 13.0 / 15.0, d3: 0.02,
            a4: 50.0, f4: 2.0, p4: 1.0, d4: 0.02,
            max_num: VERTEX_COUNT,
            padding: [0.0; 3],
            resolution: [width as f32, height as f32],
            padding2: [0.0; 2],
        }
    }

    fn create_constant_buffer(
        device: &ID3D12Device,
        params: &HarmonographParams,
    ) -> Result<ID3D12Resource> {

        // Align to 256 bytes for constant buffer
        let buffer_size = (std::mem::size_of::<HarmonographParams>() + 255) & !255;

        let mut constant_buffer: Option<ID3D12Resource> = None;
        unsafe {
            device.CreateCommittedResource(
                &D3D12_HEAP_PROPERTIES {
                    Type: D3D12_HEAP_TYPE_UPLOAD,
                    ..Default::default()
                },
                D3D12_HEAP_FLAG_NONE,
                &D3D12_RESOURCE_DESC {
                    Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
                    Width: buffer_size as u64,
                    Height: 1,
                    DepthOrArraySize: 1,
                    MipLevels: 1,
                    SampleDesc: DXGI_SAMPLE_DESC {
                        Count: 1,
                        Quality: 0,
                    },
                    Layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
                    ..Default::default()
                },
                D3D12_RESOURCE_STATE_GENERIC_READ,
                None,
                &mut constant_buffer,
            )?
        };

        let constant_buffer = constant_buffer.unwrap();

        // Copy data to constant buffer
        unsafe {
            let mut data = std::ptr::null_mut();
            constant_buffer.Map(0, None, Some(&mut data))?;
            std::ptr::copy_nonoverlapping(
                params as *const HarmonographParams,
                data as *mut HarmonographParams,
                1,
            );
            constant_buffer.Unmap(0, None);
        }

        Ok(constant_buffer)
    }

    fn next_rand(state: &mut u32) -> f32 {
        *state = state.wrapping_mul(1664525).wrapping_add(1013904223);
        ((*state >> 8) as f32) / ((u32::MAX >> 8) as f32)
    }

    fn update_harmonograph_params(resources: &mut Resources) {
        let params = &mut resources.harmonograph_params;
        params.f1 = (params.f1 + next_rand(&mut resources.rng_state) / 40.0) % 10.0;
        params.f2 = (params.f2 + next_rand(&mut resources.rng_state) / 40.0) % 10.0;
        params.f3 = (params.f3 + next_rand(&mut resources.rng_state) / 40.0) % 10.0;
        params.f4 = (params.f4 + next_rand(&mut resources.rng_state) / 40.0) % 10.0;
        params.p1 += (std::f32::consts::PI * 2.0) * 0.5 / 360.0;
        params.max_num = VERTEX_COUNT;
        params.resolution = [resources.width as f32, resources.height as f32];
    }

    fn write_constant_buffer(resources: &Resources) -> Result<()> {
        unsafe {
            let mut data = std::ptr::null_mut();
            resources.constant_buffer.Map(0, None, Some(&mut data))?;
            std::ptr::copy_nonoverlapping(
                &resources.harmonograph_params as *const HarmonographParams,
                data as *mut HarmonographParams,
                1,
            );
            resources.constant_buffer.Unmap(0, None);
        }
        Ok(())
    }

    fn create_structured_buffers(
        device: &ID3D12Device,
    ) -> Result<(ID3D12Resource, ID3D12Resource)> {
        let buffer_size = (VERTEX_COUNT as usize) * std::mem::size_of::<[f32; 4]>();

        // Position buffer (UAV)
        let mut position_buffer: Option<ID3D12Resource> = None;
        unsafe {
            device.CreateCommittedResource(
                &D3D12_HEAP_PROPERTIES {
                    Type: D3D12_HEAP_TYPE_DEFAULT,
                    ..Default::default()
                },
                D3D12_HEAP_FLAG_NONE,
                &D3D12_RESOURCE_DESC {
                    Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
                    Width: buffer_size as u64,
                    Height: 1,
                    DepthOrArraySize: 1,
                    MipLevels: 1,
                    SampleDesc: DXGI_SAMPLE_DESC {
                        Count: 1,
                        Quality: 0,
                    },
                    Layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
                    Flags: D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
                    ..Default::default()
                },
                D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                None,
                &mut position_buffer,
            )?
        };

        // Color buffer (UAV)
        let mut color_buffer: Option<ID3D12Resource> = None;
        unsafe {
            device.CreateCommittedResource(
                &D3D12_HEAP_PROPERTIES {
                    Type: D3D12_HEAP_TYPE_DEFAULT,
                    ..Default::default()
                },
                D3D12_HEAP_FLAG_NONE,
                &D3D12_RESOURCE_DESC {
                    Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
                    Width: buffer_size as u64,
                    Height: 1,
                    DepthOrArraySize: 1,
                    MipLevels: 1,
                    SampleDesc: DXGI_SAMPLE_DESC {
                        Count: 1,
                        Quality: 0,
                    },
                    Layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
                    Flags: D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS,
                    ..Default::default()
                },
                D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                None,
                &mut color_buffer,
            )?
        };

        Ok((position_buffer.unwrap(), color_buffer.unwrap()))
    }

    fn create_buffer_views(
        device: &ID3D12Device,
        heap: &ID3D12DescriptorHeap,
        constant_buffer: &ID3D12Resource,
        position_buffer: &ID3D12Resource,
        color_buffer: &ID3D12Resource,
    ) -> Result<()> {
        let descriptor_size = unsafe {
            device.GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV)
        } as usize;
        let heap_start = unsafe { heap.GetCPUDescriptorHandleForHeapStart() };

        // CBV for constant buffer (index 0)
        let cbv_desc = D3D12_CONSTANT_BUFFER_VIEW_DESC {
            BufferLocation: unsafe { constant_buffer.GetGPUVirtualAddress() },
            SizeInBytes: ((std::mem::size_of::<HarmonographParams>() + 255) & !255) as u32,
        };
        unsafe {
            device.CreateConstantBufferView(Some(&cbv_desc), heap_start);
        }

        // UAV for position buffer (index 1)
        let position_uav_desc = D3D12_UNORDERED_ACCESS_VIEW_DESC {
            Format: DXGI_FORMAT_UNKNOWN,
            ViewDimension: D3D12_UAV_DIMENSION_BUFFER,
            Anonymous: D3D12_UNORDERED_ACCESS_VIEW_DESC_0 {
                Buffer: D3D12_BUFFER_UAV {
                    FirstElement: 0,
                    NumElements: VERTEX_COUNT,
                    StructureByteStride: std::mem::size_of::<[f32; 4]>() as u32,
                    CounterOffsetInBytes: 0,
                    Flags: D3D12_BUFFER_UAV_FLAG_NONE,
                },
            },
        };
        unsafe {
            device.CreateUnorderedAccessView(
                position_buffer,
                None,
                Some(&position_uav_desc),
                D3D12_CPU_DESCRIPTOR_HANDLE {
                    ptr: heap_start.ptr + descriptor_size,
                },
            );
        }

        // UAV for color buffer (index 2)
        let color_uav_desc = D3D12_UNORDERED_ACCESS_VIEW_DESC {
            Format: DXGI_FORMAT_UNKNOWN,
            ViewDimension: D3D12_UAV_DIMENSION_BUFFER,
            Anonymous: D3D12_UNORDERED_ACCESS_VIEW_DESC_0 {
                Buffer: D3D12_BUFFER_UAV {
                    FirstElement: 0,
                    NumElements: VERTEX_COUNT,
                    StructureByteStride: std::mem::size_of::<[f32; 4]>() as u32,
                    CounterOffsetInBytes: 0,
                    Flags: D3D12_BUFFER_UAV_FLAG_NONE,
                },
            },
        };
        unsafe {
            device.CreateUnorderedAccessView(
                color_buffer,
                None,
                Some(&color_uav_desc),
                D3D12_CPU_DESCRIPTOR_HANDLE {
                    ptr: heap_start.ptr + descriptor_size * 2,
                },
            );
        }

        // SRV for position buffer (index 3)
        let position_srv_desc = D3D12_SHADER_RESOURCE_VIEW_DESC {
            Format: DXGI_FORMAT_UNKNOWN,
            ViewDimension: D3D12_SRV_DIMENSION_BUFFER,
            Shader4ComponentMapping: D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
            Anonymous: D3D12_SHADER_RESOURCE_VIEW_DESC_0 {
                Buffer: D3D12_BUFFER_SRV {
                    FirstElement: 0,
                    NumElements: VERTEX_COUNT,
                    StructureByteStride: std::mem::size_of::<[f32; 4]>() as u32,
                    Flags: D3D12_BUFFER_SRV_FLAG_NONE,
                },
            },
        };
        unsafe {
            device.CreateShaderResourceView(
                position_buffer,
                Some(&position_srv_desc),
                D3D12_CPU_DESCRIPTOR_HANDLE {
                    ptr: heap_start.ptr + descriptor_size * 3,
                },
            );
        }

        // SRV for color buffer (index 4)
        let color_srv_desc = D3D12_SHADER_RESOURCE_VIEW_DESC {
            Format: DXGI_FORMAT_UNKNOWN,
            ViewDimension: D3D12_SRV_DIMENSION_BUFFER,
            Shader4ComponentMapping: D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
            Anonymous: D3D12_SHADER_RESOURCE_VIEW_DESC_0 {
                Buffer: D3D12_BUFFER_SRV {
                    FirstElement: 0,
                    NumElements: VERTEX_COUNT,
                    StructureByteStride: std::mem::size_of::<[f32; 4]>() as u32,
                    Flags: D3D12_BUFFER_SRV_FLAG_NONE,
                },
            },
        };
        unsafe {
            device.CreateShaderResourceView(
                color_buffer,
                Some(&color_srv_desc),
                D3D12_CPU_DESCRIPTOR_HANDLE {
                    ptr: heap_start.ptr + descriptor_size * 4,
                },
            );
        }

        Ok(())
    }

    fn create_compute_root_signature(device: &ID3D12Device) -> Result<ID3D12RootSignature> {
        // Descriptor ranges for compute shader
        let ranges = [
            // CBV at b0
            D3D12_DESCRIPTOR_RANGE {
                RangeType: D3D12_DESCRIPTOR_RANGE_TYPE_CBV,
                NumDescriptors: 1,
                BaseShaderRegister: 0,
                RegisterSpace: 0,
                OffsetInDescriptorsFromTableStart: D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
            },
            // UAV at u0 (position buffer)
            D3D12_DESCRIPTOR_RANGE {
                RangeType: D3D12_DESCRIPTOR_RANGE_TYPE_UAV,
                NumDescriptors: 1,
                BaseShaderRegister: 0,
                RegisterSpace: 0,
                OffsetInDescriptorsFromTableStart: D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
            },
            // UAV at u1 (color buffer)
            D3D12_DESCRIPTOR_RANGE {
                RangeType: D3D12_DESCRIPTOR_RANGE_TYPE_UAV,
                NumDescriptors: 1,
                BaseShaderRegister: 1,
                RegisterSpace: 0,
                OffsetInDescriptorsFromTableStart: D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
            },
        ];

        let root_parameters = [
            // Parameter 0: CBV descriptor table
            D3D12_ROOT_PARAMETER {
                ParameterType: D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                Anonymous: D3D12_ROOT_PARAMETER_0 {
                    DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE {
                        NumDescriptorRanges: 1,
                        pDescriptorRanges: &ranges[0],
                    },
                },
                ShaderVisibility: D3D12_SHADER_VISIBILITY_ALL,
            },
            // Parameter 1: UAV descriptor table (position)
            D3D12_ROOT_PARAMETER {
                ParameterType: D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                Anonymous: D3D12_ROOT_PARAMETER_0 {
                    DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE {
                        NumDescriptorRanges: 1,
                        pDescriptorRanges: &ranges[1],
                    },
                },
                ShaderVisibility: D3D12_SHADER_VISIBILITY_ALL,
            },
            // Parameter 2: UAV descriptor table (color)
            D3D12_ROOT_PARAMETER {
                ParameterType: D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                Anonymous: D3D12_ROOT_PARAMETER_0 {
                    DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE {
                        NumDescriptorRanges: 1,
                        pDescriptorRanges: &ranges[2],
                    },
                },
                ShaderVisibility: D3D12_SHADER_VISIBILITY_ALL,
            },
        ];

        let desc = D3D12_ROOT_SIGNATURE_DESC {
            NumParameters: root_parameters.len() as u32,
            pParameters: root_parameters.as_ptr(),
            NumStaticSamplers: 0,
            pStaticSamplers: std::ptr::null(),
            Flags: D3D12_ROOT_SIGNATURE_FLAG_NONE,
        };

        let mut signature = None;
        let mut error = None;

        unsafe {
            D3D12SerializeRootSignature(
                &desc,
                D3D_ROOT_SIGNATURE_VERSION_1,
                &mut signature,
                Some(&mut error),
            )
        }
        .map_err(|e| {
            if let Some(err) = error {
                let msg = unsafe {
                    std::slice::from_raw_parts(
                        err.GetBufferPointer() as *const u8,
                        err.GetBufferSize(),
                    )
                };
                println!(
                    "Root signature serialization error: {}",
                    String::from_utf8_lossy(msg)
                );
            }
            e
        })?;

        let signature = signature.unwrap();

        unsafe {
            device.CreateRootSignature(
                0,
                std::slice::from_raw_parts(
                    signature.GetBufferPointer() as _,
                    signature.GetBufferSize(),
                ),
            )
        }
    }

    fn create_graphics_root_signature(device: &ID3D12Device) -> Result<ID3D12RootSignature> {
        debug_output("[create_graphics_root_signature] Creating root signature\n");
        
        // Separate descriptor ranges for each resource
        let cbv_range = [D3D12_DESCRIPTOR_RANGE {
            RangeType: D3D12_DESCRIPTOR_RANGE_TYPE_CBV,
            NumDescriptors: 1,
            BaseShaderRegister: 0,
            RegisterSpace: 0,
            OffsetInDescriptorsFromTableStart: D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
        }];
        
        let srv_range = [D3D12_DESCRIPTOR_RANGE {
            RangeType: D3D12_DESCRIPTOR_RANGE_TYPE_SRV,
            NumDescriptors: 2, // t0 and t1 are contiguous in heap (indices 3 and 4)
            BaseShaderRegister: 0,
            RegisterSpace: 0,
            OffsetInDescriptorsFromTableStart: D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
        }];

        let root_parameters = [
            // Root param 0: CBV descriptor table
            D3D12_ROOT_PARAMETER {
                ParameterType: D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                Anonymous: D3D12_ROOT_PARAMETER_0 {
                    DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE {
                        NumDescriptorRanges: 1,
                        pDescriptorRanges: cbv_range.as_ptr(),
                    },
                },
                ShaderVisibility: D3D12_SHADER_VISIBILITY_VERTEX,
            },
            // Root param 1: SRV descriptor table (position and color)
            D3D12_ROOT_PARAMETER {
                ParameterType: D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                Anonymous: D3D12_ROOT_PARAMETER_0 {
                    DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE {
                        NumDescriptorRanges: 1,
                        pDescriptorRanges: srv_range.as_ptr(),
                    },
                },
                ShaderVisibility: D3D12_SHADER_VISIBILITY_VERTEX,
            },
        ];

        let desc = D3D12_ROOT_SIGNATURE_DESC {
            NumParameters: root_parameters.len() as u32,
            pParameters: root_parameters.as_ptr(),
            NumStaticSamplers: 0,
            pStaticSamplers: std::ptr::null(),
            Flags: D3D12_ROOT_SIGNATURE_FLAG_NONE,
        };

        let mut signature = None;
        let mut error = None;

        unsafe {
            D3D12SerializeRootSignature(
                &desc,
                D3D_ROOT_SIGNATURE_VERSION_1,
                &mut signature,
                Some(&mut error),
            )
        }
        .map_err(|e| {
            if let Some(err) = error {
                let msg = unsafe {
                    std::slice::from_raw_parts(
                        err.GetBufferPointer() as *const u8,
                        err.GetBufferSize(),
                    )
                };
                println!(
                    "Root signature serialization error: {}",
                    String::from_utf8_lossy(msg)
                );
            }
            e
        })?;

        let signature = signature.unwrap();

        unsafe {
            device.CreateRootSignature(
                0,
                std::slice::from_raw_parts(
                    signature.GetBufferPointer() as _,
                    signature.GetBufferSize(),
                ),
            )
        }
    }

    fn create_compute_pipeline_state(
        device: &ID3D12Device,
        root_signature: &ID3D12RootSignature,
    ) -> Result<ID3D12PipelineState> {
        let compile_flags = if cfg!(debug_assertions) {
            D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION
        } else {
            0
        };

        let exe_path = std::env::current_exe().ok().unwrap();
        let asset_path = exe_path.parent().unwrap();
        let shaders_hlsl_path = asset_path.join("shaders.hlsl");
        let shaders_hlsl = shaders_hlsl_path.to_str().unwrap();
        let shaders_hlsl: HSTRING = shaders_hlsl.into();

        let mut compute_shader = None;
        let mut error_blob = None;

        let compute_shader = unsafe {
            D3DCompileFromFile(
                &shaders_hlsl,
                None,
                None,
                s!("CSMain"),
                s!("cs_5_0"),
                compile_flags,
                0,
                &mut compute_shader,
                Some(&mut error_blob),
            )
        }
        .map_err(|e| {
            if let Some(err) = error_blob {
                let msg = unsafe {
                    std::slice::from_raw_parts(
                        err.GetBufferPointer() as *const u8,
                        err.GetBufferSize(),
                    )
                };
                println!(
                    "Compute shader compilation error: {}",
                    String::from_utf8_lossy(msg)
                );
            }
            e
        })
        .map(|()| compute_shader.unwrap())?;

        let desc = D3D12_COMPUTE_PIPELINE_STATE_DESC {
            pRootSignature: unsafe { std::mem::transmute_copy(root_signature) },
            CS: D3D12_SHADER_BYTECODE {
                pShaderBytecode: unsafe { compute_shader.GetBufferPointer() },
                BytecodeLength: unsafe { compute_shader.GetBufferSize() },
            },
            ..Default::default()
        };

        unsafe { device.CreateComputePipelineState(&desc) }
    }

    fn create_graphics_pipeline_state(
        device: &ID3D12Device,
        root_signature: &ID3D12RootSignature,
    ) -> Result<ID3D12PipelineState> {
        let compile_flags = if cfg!(debug_assertions) {
            D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION
        } else {
            0
        };

        let exe_path = std::env::current_exe().ok().unwrap();
        let asset_path = exe_path.parent().unwrap();
        let shaders_hlsl_path = asset_path.join("shaders.hlsl");
        let shaders_hlsl = shaders_hlsl_path.to_str().unwrap();
        let shaders_hlsl: HSTRING = shaders_hlsl.into();

        let mut vertex_shader = None;
        let mut error_blob = None;

        let vertex_shader = unsafe {
            D3DCompileFromFile(
                &shaders_hlsl,
                None,
                None,
                s!("VSMain"),
                s!("vs_5_0"),
                compile_flags,
                0,
                &mut vertex_shader,
                Some(&mut error_blob),
            )
        }
        .map_err(|e| {
            if let Some(err) = error_blob {
                let msg = unsafe {
                    std::slice::from_raw_parts(
                        err.GetBufferPointer() as *const u8,
                        err.GetBufferSize(),
                    )
                };
                println!(
                    "Vertex shader compilation error: {}",
                    String::from_utf8_lossy(msg)
                );
            }
            e
        })
        .map(|()| vertex_shader.unwrap())?;

        let mut pixel_shader = None;
        error_blob = None;

        let pixel_shader = unsafe {
            D3DCompileFromFile(
                &shaders_hlsl,
                None,
                None,
                s!("PSMain"),
                s!("ps_5_0"),
                compile_flags,
                0,
                &mut pixel_shader,
                Some(&mut error_blob),
            )
        }
        .map_err(|e| {
            if let Some(err) = error_blob {
                let msg = unsafe {
                    std::slice::from_raw_parts(
                        err.GetBufferPointer() as *const u8,
                        err.GetBufferSize(),
                    )
                };
                println!(
                    "Pixel shader compilation error: {}",
                    String::from_utf8_lossy(msg)
                );
            }
            e
        })
        .map(|()| pixel_shader.unwrap())?;

        // No input layout needed - we read from structured buffer using SV_VertexID
        let desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC {
            pRootSignature: unsafe { std::mem::transmute_copy(root_signature) },
            VS: D3D12_SHADER_BYTECODE {
                pShaderBytecode: unsafe { vertex_shader.GetBufferPointer() },
                BytecodeLength: unsafe { vertex_shader.GetBufferSize() },
            },
            PS: D3D12_SHADER_BYTECODE {
                pShaderBytecode: unsafe { pixel_shader.GetBufferPointer() },
                BytecodeLength: unsafe { pixel_shader.GetBufferSize() },
            },
            RasterizerState: D3D12_RASTERIZER_DESC {
                FillMode: D3D12_FILL_MODE_SOLID,
                CullMode: D3D12_CULL_MODE_NONE,
                ..Default::default()
            },
            BlendState: D3D12_BLEND_DESC {
                AlphaToCoverageEnable: false.into(),
                IndependentBlendEnable: false.into(),
                RenderTarget: [
                    D3D12_RENDER_TARGET_BLEND_DESC {
                        BlendEnable: false.into(),
                        LogicOpEnable: false.into(),
                        SrcBlend: D3D12_BLEND_ONE,
                        DestBlend: D3D12_BLEND_ZERO,
                        BlendOp: D3D12_BLEND_OP_ADD,
                        SrcBlendAlpha: D3D12_BLEND_ONE,
                        DestBlendAlpha: D3D12_BLEND_ZERO,
                        BlendOpAlpha: D3D12_BLEND_OP_ADD,
                        LogicOp: D3D12_LOGIC_OP_NOOP,
                        RenderTargetWriteMask: D3D12_COLOR_WRITE_ENABLE_ALL.0 as u8,
                    },
                    D3D12_RENDER_TARGET_BLEND_DESC::default(),
                    D3D12_RENDER_TARGET_BLEND_DESC::default(),
                    D3D12_RENDER_TARGET_BLEND_DESC::default(),
                    D3D12_RENDER_TARGET_BLEND_DESC::default(),
                    D3D12_RENDER_TARGET_BLEND_DESC::default(),
                    D3D12_RENDER_TARGET_BLEND_DESC::default(),
                    D3D12_RENDER_TARGET_BLEND_DESC::default(),
                ],
            },
            DepthStencilState: D3D12_DEPTH_STENCIL_DESC::default(),
            SampleMask: u32::MAX,
            PrimitiveTopologyType: D3D12_PRIMITIVE_TOPOLOGY_TYPE_LINE,
            NumRenderTargets: 1,
            SampleDesc: DXGI_SAMPLE_DESC {
                Count: 1,
                ..Default::default()
            },
            RTVFormats: {
                let mut formats = [DXGI_FORMAT_UNKNOWN; 8];
                formats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
                formats
            },
            ..Default::default()
        };

        unsafe { device.CreateGraphicsPipelineState(&desc) }
    }

    fn wait_for_previous_frame(resources: &mut Resources) {
        let fence = resources.fence_value;

        unsafe { resources.command_queue.Signal(&resources.fence, fence) }
            .ok()
            .unwrap();

        resources.fence_value += 1;

        if unsafe { resources.fence.GetCompletedValue() } < fence {
            unsafe {
                resources
                    .fence
                    .SetEventOnCompletion(fence, resources.fence_event)
            }
            .ok()
            .unwrap();

            unsafe { WaitForSingleObject(resources.fence_event, INFINITE) };
        }

        resources.frame_index = unsafe { resources.swap_chain.GetCurrentBackBufferIndex() };
    }
}

fn main() -> Result<()> {
    debug_output("=== Harmonograph DirectX 12 Starting ===\n");
    run_sample::<d3d12_harmonograph::Sample>()?;
    debug_output("=== Harmonograph DirectX 12 Exiting ===\n");
    Ok(())
}

