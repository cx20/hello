// DirectX 12 Raymarching Sample in Rust
// Based on windows-rs DirectX 12 samples

use std::time::Instant;
use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Direct3D::Fxc::*,
    Win32::Graphics::Direct3D::*,
    Win32::Graphics::Direct3D12::*,
    Win32::Graphics::Dxgi::Common::*,
    Win32::Graphics::Dxgi::*,
    Win32::System::LibraryLoader::*,
    Win32::System::Threading::*,
    Win32::UI::WindowsAndMessaging::*,
};

// ============================================================================
// DXSample Trait - Interface for DirectX samples
// ============================================================================

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
        (1280, 720)
    }
}

// ============================================================================
// Command Line Parsing
// ============================================================================

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

// ============================================================================
// Main Event Loop
// ============================================================================

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
            window_rect.right - window_rect.left,
            window_rect.bottom - window_rect.top,
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
        } else {
            // No messages - render a frame
            sample.update();
            sample.render();
        }
    }

    Ok(())
}

// ============================================================================
// Window Procedure
// ============================================================================

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

// ============================================================================
// Hardware Adapter Selection
// ============================================================================

fn get_hardware_adapter(factory: &IDXGIFactory4) -> Result<IDXGIAdapter1> {
    for i in 0.. {
        let adapter = unsafe { factory.EnumAdapters1(i)? };
        let desc = unsafe { adapter.GetDesc1()? };

        if (DXGI_ADAPTER_FLAG(desc.Flags as _) & DXGI_ADAPTER_FLAG_SOFTWARE)
            != DXGI_ADAPTER_FLAG_NONE
        {
            // Skip software adapter
            continue;
        }

        // Check if adapter supports Direct3D 12
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

// ============================================================================
// Raymarching Sample Implementation
// ============================================================================

mod d3d12_raymarching {
    use super::*;

    const FRAME_COUNT: u32 = 2;

    // Constant buffer data passed to the shader
    #[repr(C)]
    #[derive(Clone, Copy)]
    struct ConstantBufferData {
        time: f32,
        resolution: [f32; 2],
        padding: f32,
    }

    // Fullscreen quad vertex
    #[repr(C)]
    #[derive(Clone, Copy)]
    struct Vertex {
        position: [f32; 2],
    }

    pub struct Sample {
        dxgi_factory: IDXGIFactory4,
        device: ID3D12Device,
        resources: Option<Resources>,
        start_time: Instant,
    }

    struct Resources {
        command_queue: ID3D12CommandQueue,
        swap_chain: IDXGISwapChain3,
        frame_index: u32,
        render_targets: [ID3D12Resource; FRAME_COUNT as usize],
        rtv_heap: ID3D12DescriptorHeap,
        rtv_descriptor_size: usize,
        viewport: D3D12_VIEWPORT,
        scissor_rect: RECT,
        command_allocator: ID3D12CommandAllocator,
        root_signature: ID3D12RootSignature,
        pso: ID3D12PipelineState,
        command_list: ID3D12GraphicsCommandList,

        // Vertex buffer for fullscreen quad
        #[allow(dead_code)]
        vertex_buffer: ID3D12Resource,
        vbv: D3D12_VERTEX_BUFFER_VIEW,

        // Index buffer for fullscreen quad
        #[allow(dead_code)]
        index_buffer: ID3D12Resource,
        ibv: D3D12_INDEX_BUFFER_VIEW,

        // Constant buffer for shader parameters
        constant_buffer: ID3D12Resource,
        cbv_heap: ID3D12DescriptorHeap,
        cb_data_ptr: *mut ConstantBufferData,

        // Synchronization objects
        fence: ID3D12Fence,
        fence_value: u64,
        fence_event: HANDLE,

        // Window dimensions
        width: u32,
        height: u32,
    }

    impl DXSample for Sample {
        fn new(command_line: &SampleCommandLine) -> Result<Self> {
            let (dxgi_factory, device) = create_device(command_line)?;

            Ok(Sample {
                dxgi_factory,
                device,
                resources: None,
                start_time: Instant::now(),
            })
        }

        fn bind_to_window(&mut self, hwnd: &HWND) -> Result<()> {
            let command_queue: ID3D12CommandQueue = unsafe {
                self.device.CreateCommandQueue(&D3D12_COMMAND_QUEUE_DESC {
                    Type: D3D12_COMMAND_LIST_TYPE_DIRECT,
                    ..Default::default()
                })?
            };

            let (width, height) = self.window_size();

            let swap_chain_desc = DXGI_SWAP_CHAIN_DESC1 {
                BufferCount: FRAME_COUNT,
                Width: width as u32,
                Height: height as u32,
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

            // Disable fullscreen transitions
            unsafe {
                self.dxgi_factory
                    .MakeWindowAssociation(*hwnd, DXGI_MWA_NO_ALT_ENTER)?;
            }

            let frame_index = unsafe { swap_chain.GetCurrentBackBufferIndex() };

            // Create RTV descriptor heap
            let rtv_heap: ID3D12DescriptorHeap = unsafe {
                self.device
                    .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
                        NumDescriptors: FRAME_COUNT,
                        Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
                        ..Default::default()
                    })
            }?;

            let rtv_descriptor_size = unsafe {
                self.device
                    .GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV)
            } as usize;
            let rtv_handle = unsafe { rtv_heap.GetCPUDescriptorHandleForHeapStart() };

            // Create render targets
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
                right: width,
                bottom: height,
            };

            let command_allocator = unsafe {
                self.device
                    .CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT)
            }?;

            // Create CBV descriptor heap
            let cbv_heap: ID3D12DescriptorHeap = unsafe {
                self.device
                    .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
                        NumDescriptors: 1,
                        Type: D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,
                        Flags: D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
                        ..Default::default()
                    })
            }?;

            // Create constant buffer
            let (constant_buffer, cb_data_ptr) =
                create_constant_buffer(&self.device, &cbv_heap, width as u32, height as u32)?;

            let root_signature = create_root_signature(&self.device)?;
            let pso = create_pipeline_state(&self.device, &root_signature)?;

            let command_list: ID3D12GraphicsCommandList = unsafe {
                self.device.CreateCommandList(
                    0,
                    D3D12_COMMAND_LIST_TYPE_DIRECT,
                    &command_allocator,
                    &pso,
                )
            }?;
            unsafe {
                command_list.Close()?;
            };

            let (vertex_buffer, vbv) = create_vertex_buffer(&self.device)?;
            let (index_buffer, ibv) = create_index_buffer(&self.device)?;

            let fence = unsafe { self.device.CreateFence(0, D3D12_FENCE_FLAG_NONE) }?;
            let fence_value = 1;
            let fence_event = unsafe { CreateEventA(None, false, false, None)? };

            self.resources = Some(Resources {
                command_queue,
                swap_chain,
                frame_index,
                render_targets,
                rtv_heap,
                rtv_descriptor_size,
                viewport,
                scissor_rect,
                command_allocator,
                root_signature,
                pso,
                command_list,
                vertex_buffer,
                vbv,
                index_buffer,
                ibv,
                constant_buffer,
                cbv_heap,
                cb_data_ptr,
                fence,
                fence_value,
                fence_event,
                width: width as u32,
                height: height as u32,
            });

            Ok(())
        }

        fn title(&self) -> String {
            "DirectX 12 Raymarching".into()
        }

        fn window_size(&self) -> (i32, i32) {
            (1280, 720)
        }

        fn update(&mut self) {
            if let Some(resources) = &mut self.resources {
                // Update constant buffer with current time
                let elapsed = self.start_time.elapsed().as_secs_f32();
                unsafe {
                    (*resources.cb_data_ptr).time = elapsed;
                    (*resources.cb_data_ptr).resolution =
                        [resources.width as f32, resources.height as f32];
                }
            }
        }

        fn render(&mut self) {
            if let Some(resources) = &mut self.resources {
                populate_command_list(resources).unwrap();

                // Execute the command list
                let command_list = Some(resources.command_list.cast().unwrap());
                unsafe { resources.command_queue.ExecuteCommandLists(&[command_list]) };

                // Present the frame
                unsafe { resources.swap_chain.Present(1, DXGI_PRESENT(0)) }
                    .ok()
                    .unwrap();

                wait_for_previous_frame(resources);
            }
        }
    }

    // ========================================================================
    // Command List Population
    // ========================================================================

    fn populate_command_list(resources: &Resources) -> Result<()> {
        unsafe {
            resources.command_allocator.Reset()?;
        }

        let command_list = &resources.command_list;

        unsafe {
            command_list.Reset(&resources.command_allocator, &resources.pso)?;
        }

        // Set necessary state
        unsafe {
            command_list.SetGraphicsRootSignature(&resources.root_signature);

            // Set descriptor heaps
            command_list.SetDescriptorHeaps(&[Some(resources.cbv_heap.clone())]);

            // Set the CBV
            command_list.SetGraphicsRootDescriptorTable(
                0,
                resources.cbv_heap.GetGPUDescriptorHandleForHeapStart(),
            );

            command_list.RSSetViewports(&[resources.viewport]);
            command_list.RSSetScissorRects(&[resources.scissor_rect]);
        }

        // Transition back buffer to render target
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

        unsafe { command_list.OMSetRenderTargets(1, Some(&rtv_handle), false, None) };

        // Record draw commands
        unsafe {
            command_list.ClearRenderTargetView(
                rtv_handle,
                &[0.0_f32, 0.0_f32, 0.0_f32, 1.0_f32],
                None,
            );
            command_list.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
            command_list.IASetVertexBuffers(0, Some(&[resources.vbv]));
            command_list.IASetIndexBuffer(Some(&resources.ibv));
            command_list.DrawIndexedInstanced(6, 1, 0, 0, 0);

            // Transition back buffer to present state
            command_list.ResourceBarrier(&[transition_barrier(
                &resources.render_targets[resources.frame_index as usize],
                D3D12_RESOURCE_STATE_RENDER_TARGET,
                D3D12_RESOURCE_STATE_PRESENT,
            )]);
        }

        unsafe { command_list.Close() }
    }

    // ========================================================================
    // Resource Barrier Helper
    // ========================================================================

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

    // ========================================================================
    // Device Creation
    // ========================================================================

    fn create_device(command_line: &SampleCommandLine) -> Result<(IDXGIFactory4, ID3D12Device)> {
        if cfg!(debug_assertions) {
            unsafe {
                let mut debug: Option<ID3D12Debug> = None;
                if let Some(debug) = D3D12GetDebugInterface(&mut debug).ok().and(debug) {
                    debug.EnableDebugLayer();
                }
            }
        }

        let dxgi_factory_flags = if cfg!(debug_assertions) {
            DXGI_CREATE_FACTORY_DEBUG
        } else {
            DXGI_CREATE_FACTORY_FLAGS(0)
        };

        let dxgi_factory: IDXGIFactory4 = unsafe { CreateDXGIFactory2(dxgi_factory_flags) }?;

        let adapter = if command_line.use_warp_device {
            unsafe { dxgi_factory.EnumWarpAdapter() }
        } else {
            get_hardware_adapter(&dxgi_factory)
        }?;

        let mut device: Option<ID3D12Device> = None;
        unsafe { D3D12CreateDevice(&adapter, D3D_FEATURE_LEVEL_11_0, &mut device) }?;
        Ok((dxgi_factory, device.unwrap()))
    }

    // ========================================================================
    // Root Signature Creation
    // ========================================================================

    fn create_root_signature(device: &ID3D12Device) -> Result<ID3D12RootSignature> {
        // Define descriptor range for CBV
        let descriptor_range = D3D12_DESCRIPTOR_RANGE {
            RangeType: D3D12_DESCRIPTOR_RANGE_TYPE_CBV,
            NumDescriptors: 1,
            BaseShaderRegister: 0,
            RegisterSpace: 0,
            OffsetInDescriptorsFromTableStart: D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
        };

        // Root parameter for descriptor table
        let root_parameter = D3D12_ROOT_PARAMETER {
            ParameterType: D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
            Anonymous: D3D12_ROOT_PARAMETER_0 {
                DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE {
                    NumDescriptorRanges: 1,
                    pDescriptorRanges: &descriptor_range,
                },
            },
            ShaderVisibility: D3D12_SHADER_VISIBILITY_PIXEL,
        };

        let desc = D3D12_ROOT_SIGNATURE_DESC {
            NumParameters: 1,
            pParameters: &root_parameter,
            NumStaticSamplers: 0,
            pStaticSamplers: std::ptr::null(),
            Flags: D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
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
            if let Some(err_blob) = error {
                let err_msg = unsafe {
                    std::slice::from_raw_parts(
                        err_blob.GetBufferPointer() as *const u8,
                        err_blob.GetBufferSize(),
                    )
                };
                println!(
                    "Root signature error: {}",
                    String::from_utf8_lossy(err_msg)
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

    // ========================================================================
    // Pipeline State Object Creation
    // ========================================================================

    fn create_pipeline_state(
        device: &ID3D12Device,
        root_signature: &ID3D12RootSignature,
    ) -> Result<ID3D12PipelineState> {
        let compile_flags = if cfg!(debug_assertions) {
            D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION
        } else {
            0
        };

        // Load shader from file
        let exe_path = std::env::current_exe().ok().unwrap();
        let asset_path = exe_path.parent().unwrap();
        let shaders_hlsl_path = asset_path.join("shaders.hlsl");
        let shaders_hlsl = shaders_hlsl_path.to_str().unwrap();
        let shaders_hlsl: HSTRING = shaders_hlsl.into();

        // Compile vertex shader
        let mut vertex_shader = None;
        let mut vs_error = None;
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
                Some(&mut vs_error),
            )
        }
        .map_err(|e| {
            if let Some(err_blob) = vs_error {
                let err_msg = unsafe {
                    std::slice::from_raw_parts(
                        err_blob.GetBufferPointer() as *const u8,
                        err_blob.GetBufferSize(),
                    )
                };
                println!(
                    "Vertex shader error: {}",
                    String::from_utf8_lossy(err_msg)
                );
            }
            e
        })
        .map(|()| vertex_shader.unwrap())?;

        // Compile pixel shader
        let mut pixel_shader = None;
        let mut ps_error = None;
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
                Some(&mut ps_error),
            )
        }
        .map_err(|e| {
            if let Some(err_blob) = ps_error {
                let err_msg = unsafe {
                    std::slice::from_raw_parts(
                        err_blob.GetBufferPointer() as *const u8,
                        err_blob.GetBufferSize(),
                    )
                };
                println!("Pixel shader error: {}", String::from_utf8_lossy(err_msg));
            }
            e
        })
        .map(|()| pixel_shader.unwrap())?;

        // Input layout for fullscreen quad (just position)
        let mut input_element_descs: [D3D12_INPUT_ELEMENT_DESC; 1] = [D3D12_INPUT_ELEMENT_DESC {
            SemanticName: s!("POSITION"),
            SemanticIndex: 0,
            Format: DXGI_FORMAT_R32G32_FLOAT,
            InputSlot: 0,
            AlignedByteOffset: 0,
            InputSlotClass: D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
            InstanceDataStepRate: 0,
        }];

        let mut desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC {
            InputLayout: D3D12_INPUT_LAYOUT_DESC {
                pInputElementDescs: input_element_descs.as_mut_ptr(),
                NumElements: input_element_descs.len() as u32,
            },
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
            SampleMask: u32::max_value(),
            PrimitiveTopologyType: D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE,
            NumRenderTargets: 1,
            SampleDesc: DXGI_SAMPLE_DESC {
                Count: 1,
                ..Default::default()
            },
            ..Default::default()
        };
        desc.RTVFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;

        unsafe { device.CreateGraphicsPipelineState(&desc) }
    }

    // ========================================================================
    // Vertex Buffer Creation (Fullscreen Quad)
    // ========================================================================

    fn create_vertex_buffer(device: &ID3D12Device) -> Result<(ID3D12Resource, D3D12_VERTEX_BUFFER_VIEW)>
    {
        // Fullscreen quad vertices in NDC
        let vertices = [
            Vertex { position: [-1.0, -1.0] }, // Bottom-left
            Vertex { position: [-1.0, 1.0] },  // Top-left
            Vertex { position: [1.0, 1.0] },   // Top-right
            Vertex { position: [1.0, -1.0] },  // Bottom-right
        ];

        let mut vertex_buffer: Option<ID3D12Resource> = None;
        unsafe {
            device.CreateCommittedResource(
                &D3D12_HEAP_PROPERTIES {
                    Type: D3D12_HEAP_TYPE_UPLOAD,
                    ..Default::default()
                },
                D3D12_HEAP_FLAG_NONE,
                &D3D12_RESOURCE_DESC {
                    Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
                    Width: std::mem::size_of_val(&vertices) as u64,
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
                &mut vertex_buffer,
            )?
        };
        let vertex_buffer = vertex_buffer.unwrap();

        // Copy vertex data to buffer
        unsafe {
            let mut data = std::ptr::null_mut();
            vertex_buffer.Map(0, None, Some(&mut data))?;
            std::ptr::copy_nonoverlapping(vertices.as_ptr(), data as *mut Vertex, vertices.len());
            vertex_buffer.Unmap(0, None);
        }

        let vbv = D3D12_VERTEX_BUFFER_VIEW {
            BufferLocation: unsafe { vertex_buffer.GetGPUVirtualAddress() },
            StrideInBytes: std::mem::size_of::<Vertex>() as u32,
            SizeInBytes: std::mem::size_of_val(&vertices) as u32,
        };

        Ok((vertex_buffer, vbv))
    }

    // ========================================================================
    // Index Buffer Creation
    // ========================================================================

    fn create_index_buffer(device: &ID3D12Device) -> Result<(ID3D12Resource, D3D12_INDEX_BUFFER_VIEW)>
    {
        // Two triangles to form a quad
        let indices: [u16; 6] = [
            0, 1, 2, // First triangle
            0, 2, 3, // Second triangle
        ];

        let mut index_buffer: Option<ID3D12Resource> = None;
        unsafe {
            device.CreateCommittedResource(
                &D3D12_HEAP_PROPERTIES {
                    Type: D3D12_HEAP_TYPE_UPLOAD,
                    ..Default::default()
                },
                D3D12_HEAP_FLAG_NONE,
                &D3D12_RESOURCE_DESC {
                    Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
                    Width: std::mem::size_of_val(&indices) as u64,
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
                &mut index_buffer,
            )?
        };
        let index_buffer = index_buffer.unwrap();

        // Copy index data to buffer
        unsafe {
            let mut data = std::ptr::null_mut();
            index_buffer.Map(0, None, Some(&mut data))?;
            std::ptr::copy_nonoverlapping(indices.as_ptr(), data as *mut u16, indices.len());
            index_buffer.Unmap(0, None);
        }

        let ibv = D3D12_INDEX_BUFFER_VIEW {
            BufferLocation: unsafe { index_buffer.GetGPUVirtualAddress() },
            SizeInBytes: std::mem::size_of_val(&indices) as u32,
            Format: DXGI_FORMAT_R16_UINT,
        };

        Ok((index_buffer, ibv))
    }

    // ========================================================================
    // Constant Buffer Creation
    // ========================================================================

    fn create_constant_buffer(
        device: &ID3D12Device,
        cbv_heap: &ID3D12DescriptorHeap,
        width: u32,
        height: u32,
    ) -> Result<(ID3D12Resource, *mut ConstantBufferData)> {
        // Constant buffer size must be 256-byte aligned
        let cb_size = (std::mem::size_of::<ConstantBufferData>() + 255) & !255;

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
                    Width: cb_size as u64,
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

        // Create constant buffer view
        let cbv_desc = D3D12_CONSTANT_BUFFER_VIEW_DESC {
            BufferLocation: unsafe { constant_buffer.GetGPUVirtualAddress() },
            SizeInBytes: cb_size as u32,
        };

        unsafe {
            device.CreateConstantBufferView(
                Some(&cbv_desc),
                cbv_heap.GetCPUDescriptorHandleForHeapStart(),
            );
        }

        // Map buffer and initialize data
        let mut data_ptr: *mut std::ffi::c_void = std::ptr::null_mut();
        unsafe {
            constant_buffer.Map(0, None, Some(&mut data_ptr))?;
        }

        let cb_data_ptr = data_ptr as *mut ConstantBufferData;
        unsafe {
            (*cb_data_ptr).time = 0.0;
            (*cb_data_ptr).resolution = [width as f32, height as f32];
            (*cb_data_ptr).padding = 0.0;
        }

        Ok((constant_buffer, cb_data_ptr))
    }

    // ========================================================================
    // Frame Synchronization
    // ========================================================================

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

// ============================================================================
// Entry Point
// ============================================================================

fn main() -> Result<()> {
    run_sample::<d3d12_raymarching::Sample>()?;
    Ok(())
}