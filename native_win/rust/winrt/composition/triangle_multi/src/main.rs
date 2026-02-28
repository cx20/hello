// Rust port of hello.c
// Win32 window + OpenGL/D3D11/Vulkan triangle rendering composited via
// Windows.UI.Composition Desktop interop (DesktopWindowTarget).
//
// Architecture:
//   - One Win32 HWND with WS_EX_NOREDIRECTIONBITMAP
//   - One shared D3D11 device
//   - Three DXGI swap chains created with CreateSwapChainForComposition
//   - Windows.UI.Composition: Compositor -> DesktopWindowTarget
//     -> ContainerVisual -> 3 SpriteVisuals (one per panel)
//   - OpenGL panel: renders via WGL_NV_DX_interop into D3D11 back buffer
//   - D3D11 panel: renders directly to its own swap chain
//   - Vulkan panel: renders offscreen, CPU-readback copies to D3D11 staging tex
//
// Build prerequisites:
//   - Vulkan SDK (for ash/vulkan-1.lib)
//   - SPIR-V shaders: compile hello.vert / hello.frag with glslangValidator
//       glslangValidator -V hello.vert -o hello_vert.spv
//       glslangValidator -V hello.frag -o hello_frag.spv
//   - NVIDIA GPU with WGL_NV_DX_interop support (for the OpenGL panel)

#![windows_subsystem = "windows"]


use std::mem::zeroed;
use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Gdi::*,
    Win32::System::Com::*,
    Win32::System::LibraryLoader::GetModuleHandleW,
        Win32::UI::WindowsAndMessaging::*,
};

// Panel dimensions
pub const PANEL_WIDTH: u32 = 320;
pub const PANEL_HEIGHT: u32 = 480;
pub const WINDOW_WIDTH: u32 = PANEL_WIDTH * 3; // 3 panels side by side

// Extended window style not always in bindings
const WS_EX_NOREDIRECTIONBITMAP: WINDOW_EX_STYLE = WINDOW_EX_STYLE(0x00200000);

/// Application state holding all graphics resources
struct AppState {
    d3d: d3d11::D3D11State,
    _comp: composition::CompositionState,
    gl: opengl::OpenGLState,
    vk: vulkan_panel::VulkanState,
}

fn main() -> Result<()> {
    unsafe {
        // Initialize COM (STA for Composition)
        CoInitializeEx(None, COINIT_APARTMENTTHREADED).ok()?;

        let hwnd = create_app_window()?;

        // Initialize D3D11 device and all three swap chains
        let d3d = d3d11::init_d3d11_and_swap_chains()?;

        // Initialize Windows.UI.Composition
        let comp = composition::init_composition(hwnd, &d3d)?;

        // Initialize OpenGL panel (WGL_NV_DX_interop)
        let gl = opengl::init_opengl(hwnd, &d3d)?;

        // Initialize Vulkan panel (offscreen rendering)
        let vk = vulkan_panel::init_vulkan(&d3d)?;

        let mut state = AppState {
            d3d,
            _comp: comp,
            gl,
            vk,
        };

        // Message loop with continuous rendering
        let mut msg: MSG = zeroed();
        loop {
            if PeekMessageW(&mut msg, Some(HWND::default()), 0, 0, PM_REMOVE).as_bool() {
                if msg.message == WM_QUIT {
                    break;
                }
                let _ = TranslateMessage(&msg);
                DispatchMessageW(&msg);
            } else {
                render(&mut state);
            }
        }

        // Cleanup (Drop impls will handle most of it)
        drop(state);
        CoUninitialize();

        Ok(())
    }
}

/// Create the application window with WS_EX_NOREDIRECTIONBITMAP
unsafe fn create_app_window() -> Result<HWND> {
    let instance = GetModuleHandleW(None)?;
    let class_name = w!("Win32CompTriangleRust");

    let wc = WNDCLASSEXW {
        cbSize: std::mem::size_of::<WNDCLASSEXW>() as u32,
        hInstance: instance.into(),
        lpszClassName: class_name,
        lpfnWndProc: Some(wnd_proc),
        hCursor: LoadCursorW(None, IDC_ARROW)?,
        hbrBackground: HBRUSH::default(), // No GDI background
        ..zeroed()
    };

    let atom = RegisterClassExW(&wc);
    if atom == 0 {
        let err = GetLastError();
        if err != WIN32_ERROR(0x582) {
            // ERROR_CLASS_ALREADY_EXISTS
            return Err(err.into());
        }
    }

    let style = WS_OVERLAPPEDWINDOW;
    let mut rc = RECT {
        left: 0,
        top: 0,
        right: WINDOW_WIDTH as i32,
        bottom: PANEL_HEIGHT as i32,
    };
    AdjustWindowRect(&mut rc, style, false)?;

    let hwnd = CreateWindowExW(
        WS_EX_NOREDIRECTIONBITMAP,
        class_name,
        w!("OpenGL + D3D11 + Vulkan via Windows.UI.Composition (Rust)"),
        style,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        rc.right - rc.left,
        rc.bottom - rc.top,
        None,
        None,
        Some(instance.into()),
        None,
    )?;

    let _ = ShowWindow(hwnd, SW_SHOW);
    let _ = UpdateWindow(hwnd);

    Ok(hwnd)
}

/// Window procedure
unsafe extern "system" fn wnd_proc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    match msg {
        WM_DESTROY => {
            PostQuitMessage(0);
            LRESULT(0)
        }
        WM_PAINT => {
            let mut ps = PAINTSTRUCT::default();
            let _hdc = BeginPaint(hwnd, &mut ps);
            let _ = EndPaint(hwnd, &ps);
            LRESULT(0)
        }
        _ => DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

/// Render all three panels
unsafe fn render(state: &mut AppState) {
    // Panel 1: OpenGL (via WGL_NV_DX_interop -> D3D11 swap chain)
    opengl::render_opengl_panel(&state.gl, &state.d3d);

    // Panel 2: D3D11 (direct rendering)
    d3d11::render_d3d11_panel(&state.d3d);

    // Panel 3: Vulkan (offscreen -> CPU readback -> D3D11 copy)
    vulkan_panel::render_vulkan_panel(&state.vk, &state.d3d);
}


mod composition {
// Windows.UI.Composition setup.
//
// Creates Compositor, DesktopWindowTarget, and wires three DXGI swap chains
// as composition surfaces displayed via SpriteVisuals inside a ContainerVisual.
//
// Flow:
//   1. Create DispatcherQueueController (required by Composition)
//   2. Activate Compositor via WinRT
//   3. QI ICompositorDesktopInterop -> CreateDesktopWindowTarget(HWND)
//   4. Create root ContainerVisual and set as target root
//   5. QI ICompositorInterop -> wrap each swap chain as ICompositionSurface
//   6. Create SpriteVisual + SurfaceBrush for each panel, add to root

use crate::d3d11::D3D11State;
use crate::{PANEL_HEIGHT, PANEL_WIDTH};
use windows_numerics::{Vector2, Vector3};
use windows::{
    core::*,
    
    UI::Composition::*,
    UI::Composition::Desktop::DesktopWindowTarget,
    Win32::Foundation::*,
    Win32::System::WinRT::*,
    Win32::System::WinRT::Composition::*,
};

#[repr(C)]
#[allow(non_snake_case)]
struct DispatcherQueueOptionsRaw {
    dwSize: u32,
    threadType: i32,
    apartmentType: i32,
}

#[link(name = "CoreMessaging")]
unsafe extern "system" {
    fn CreateDispatcherQueueController(
        options: DispatcherQueueOptionsRaw,
        dispatcherqueuecontroller: *mut *mut core::ffi::c_void,
    ) -> HRESULT;
}

/// Holds all Composition objects (prevent premature release)
pub struct CompositionState {
    _compositor: Compositor,
    _desktop_target: DesktopWindowTarget,
    _root_visual: ContainerVisual,
    _dq_controller: IInspectable,

    // Per-panel composition objects
    _gl_surface: ICompositionSurface,
    _gl_sprite: SpriteVisual,
    _dx_surface: ICompositionSurface,
    _dx_sprite: SpriteVisual,
    _vk_surface: ICompositionSurface,
    _vk_sprite: SpriteVisual,
}

/// Create a SpriteVisual that displays a swap chain surface at the given X offset
unsafe fn add_sprite_for_swap_chain(
    compositor: &Compositor,
    comp_interop: &ICompositorInterop,
    collection: &VisualCollection,
    swap_chain: &windows::Win32::Graphics::Dxgi::IDXGISwapChain1,
    offset_x: f32,
) -> Result<(ICompositionSurface, SpriteVisual)> {
    // Wrap swap chain as ICompositionSurface
    let swap_chain_unknown: IUnknown = swap_chain.cast()?;
    let surface: ICompositionSurface =
        comp_interop.CreateCompositionSurfaceForSwapChain(&swap_chain_unknown)?;

    // Create surface brush from the composition surface
    let brush = compositor.CreateSurfaceBrushWithSurface(&surface)?;

    // Create SpriteVisual and assign the brush
    let sprite = compositor.CreateSpriteVisual()?;
    let composition_brush: CompositionBrush = brush.cast()?;
    sprite.SetBrush(&composition_brush)?;

    // Set size and offset
    let visual: Visual = sprite.cast()?;
    visual.SetSize(Vector2 {
        X: PANEL_WIDTH as f32,
        Y: PANEL_HEIGHT as f32,
    })?;
    visual.SetOffset(Vector3 {
        X: offset_x,
        Y: 0.0,
        Z: 0.0,
    })?;

    // Insert into the visual tree
    let visual_for_insert: Visual = sprite.cast()?;
    collection.InsertAtTop(&visual_for_insert)?;

    Ok((surface, sprite))
}

/// Initialize the Composition visual tree for the given HWND
pub unsafe fn init_composition(hwnd: HWND, d3d: &D3D11State) -> Result<CompositionState> {
    // Create DispatcherQueueController (needed before Composition calls)
    let options = DispatcherQueueOptionsRaw {
        dwSize: std::mem::size_of::<DispatcherQueueOptionsRaw>() as u32,
        threadType: DQTYPE_THREAD_CURRENT.0,
        apartmentType: DQTAT_COM_ASTA.0,
    };
    let dq_controller: IInspectable = {
        // Cast the output to IInspectable (the function returns DispatcherQueueController)
        let mut raw: *mut std::ffi::c_void = std::ptr::null_mut();
        let hr = CreateDispatcherQueueController(
            options,
            &mut raw as *mut _ as *mut *mut std::ffi::c_void,
        );
        if hr.is_err() {
            return Err(hr.into());
        }
        // The returned object is an IInspectable -- take ownership
        IInspectable::from_raw(raw)
    };

    // Activate Compositor
    let compositor = Compositor::new()?;

    // QI for ICompositorDesktopInterop to create DesktopWindowTarget
    let desktop_interop: ICompositorDesktopInterop = compositor.cast()?;
    let desktop_target: DesktopWindowTarget =
        desktop_interop.CreateDesktopWindowTarget(hwnd, false)?;

    // Create root ContainerVisual and set on target
    let root_visual = compositor.CreateContainerVisual()?;
    let root_as_visual: Visual = root_visual.cast()?;
    let target: CompositionTarget = desktop_target.cast()?;
    target.SetRoot(&root_as_visual)?;

    // Get visual collection from root
    let collection = root_visual.Children()?;

    // QI for ICompositorInterop to wrap swap chains as surfaces
    let comp_interop: ICompositorInterop = compositor.cast()?;

    // Panel 0 (left): OpenGL swap chain at x=0
    let (gl_surface, gl_sprite) = add_sprite_for_swap_chain(
        &compositor,
        &comp_interop,
        &collection,
        &d3d.gl_swap_chain,
        0.0,
    )?;

    // Panel 1 (center): D3D11 swap chain at x=PANEL_WIDTH
    let (dx_surface, dx_sprite) = add_sprite_for_swap_chain(
        &compositor,
        &comp_interop,
        &collection,
        &d3d.dx_swap_chain,
        PANEL_WIDTH as f32,
    )?;

    // Panel 2 (right): Vulkan swap chain at x=PANEL_WIDTH*2
    let (vk_surface, vk_sprite) = add_sprite_for_swap_chain(
        &compositor,
        &comp_interop,
        &collection,
        &d3d.vk_swap_chain,
        (PANEL_WIDTH * 2) as f32,
    )?;

    Ok(CompositionState {
        _compositor: compositor,
        _desktop_target: desktop_target,
        _root_visual: root_visual,
        _dq_controller: dq_controller,
        _gl_surface: gl_surface,
        _gl_sprite: gl_sprite,
        _dx_surface: dx_surface,
        _dx_sprite: dx_sprite,
        _vk_surface: vk_surface,
        _vk_sprite: vk_sprite,
    })
}

}

mod d3d11 {
// D3D11 device, DXGI swap chains for composition, and D3D11 panel rendering.
//
// Creates one shared D3D11 device and three swap chains via
// CreateSwapChainForComposition. The D3D11 panel renders a colored
// triangle directly; the other two swap chains are used by OpenGL
// and Vulkan modules respectively.

use crate::{PANEL_HEIGHT, PANEL_WIDTH};
use std::ffi::CString;
use std::mem::zeroed;
use windows::{
    core::*,
    Win32::Foundation::E_FAIL,
    Win32::Graphics::Direct3D::*,
    Win32::Graphics::Direct3D11::*,
    Win32::Graphics::Direct3D::Fxc::*,
    Win32::Graphics::Dxgi::Common::*,
    Win32::Graphics::Dxgi::*,
};

// HLSL vertex shader source (embedded)
const VS_HLSL: &str = r#"
struct VSInput  { float3 pos : POSITION; float4 col : COLOR; };
struct VSOutput { float4 pos : SV_POSITION; float4 col : COLOR; };
VSOutput main(VSInput i) {
    VSOutput o;
    o.pos = float4(i.pos, 1);
    o.col = i.col;
    return o;
}
"#;

// HLSL pixel shader source (embedded)
const PS_HLSL: &str = r#"
struct PSInput { float4 pos : SV_POSITION; float4 col : COLOR; };
float4 main(PSInput i) : SV_TARGET { return i.col; }
"#;

/// Vertex with position (xyz) and color (rgba)
#[repr(C)]
#[derive(Clone, Copy)]
pub struct Vertex {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

/// Holds all D3D11 / DXGI state
pub struct D3D11State {
    pub device: ID3D11Device,
    pub context: ID3D11DeviceContext,

    // OpenGL panel swap chain (panel 0, left)
    pub gl_swap_chain: IDXGISwapChain1,
    pub gl_back_buffer: ID3D11Texture2D,

    // D3D11 panel swap chain (panel 1, center)
    pub dx_swap_chain: IDXGISwapChain1,
    pub dx_rtv: ID3D11RenderTargetView,

    // Vulkan panel swap chain (panel 2, right)
    pub vk_swap_chain: IDXGISwapChain1,
    pub vk_back_buffer: ID3D11Texture2D,
    pub vk_staging_tex: ID3D11Texture2D,

    // D3D11 rendering pipeline (shared for D3D11 panel)
    pub vs: ID3D11VertexShader,
    pub ps: ID3D11PixelShader,
    pub input_layout: ID3D11InputLayout,
    pub vertex_buffer: ID3D11Buffer,
}

/// Compile an HLSL shader from source string
unsafe fn compile_shader(source: &str, entry: &str, target: &str) -> Result<ID3DBlob> {
    let src_bytes = source.as_bytes();
    let entry_cstr = CString::new(entry).unwrap();
    let target_cstr = CString::new(target).unwrap();

    let mut blob: Option<ID3DBlob> = None;
    let mut err_blob: Option<ID3DBlob> = None;

    let hr = D3DCompile(
        src_bytes.as_ptr() as *const _,
        src_bytes.len(),
        None,
        None,
        None,
        PCSTR(entry_cstr.as_ptr() as *const u8),
        PCSTR(target_cstr.as_ptr() as *const u8),
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        &mut blob,
        Some(&mut err_blob),
    );

    if let Err(e) = hr {
        if let Some(err) = err_blob {
            let msg = std::slice::from_raw_parts(
                err.GetBufferPointer() as *const u8,
                err.GetBufferSize(),
            );
            let msg_str = String::from_utf8_lossy(msg);
            return Err(Error::new(e.code(), msg_str.as_ref()));
        }
        return Err(e);
    }

    blob.ok_or_else(|| Error::new(E_FAIL, "D3DCompile returned no blob"))
}

/// Create a DXGI swap chain for composition on the shared D3D11 device
unsafe fn create_swap_chain_for_composition(device: &ID3D11Device) -> Result<IDXGISwapChain1> {
    let dxgi_device: IDXGIDevice = device.cast()?;
    let adapter: IDXGIAdapter = dxgi_device.GetAdapter()?;
    let factory: IDXGIFactory2 = adapter.GetParent()?;

    let desc = DXGI_SWAP_CHAIN_DESC1 {
        Width: PANEL_WIDTH,
        Height: PANEL_HEIGHT,
        Format: DXGI_FORMAT_B8G8R8A8_UNORM,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
        BufferCount: 2,
        Scaling: DXGI_SCALING_STRETCH,
        SwapEffect: DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL,
        AlphaMode: DXGI_ALPHA_MODE_PREMULTIPLIED,
        ..zeroed()
    };

    let swap_chain = factory.CreateSwapChainForComposition(device, &desc, None)?;
    Ok(swap_chain)
}

/// Create a render target view from a swap chain's back buffer
unsafe fn create_rtv(
    device: &ID3D11Device,
    swap_chain: &IDXGISwapChain1,
) -> Result<(ID3D11Texture2D, ID3D11RenderTargetView)> {
    let back_buffer: ID3D11Texture2D = swap_chain.GetBuffer(0)?;
    let mut rtv: Option<ID3D11RenderTargetView> = None;
    device.CreateRenderTargetView(&back_buffer, None, Some(&mut rtv))?;
    let rtv = rtv.ok_or_else(|| Error::new(E_FAIL, "CreateRenderTargetView failed"))?;
    Ok((back_buffer, rtv))
}

/// Initialize D3D11 device and all three swap chains
pub unsafe fn init_d3d11_and_swap_chains() -> Result<D3D11State> {
    // Create D3D11 device (BGRA support required for Composition)
    let mut device: Option<ID3D11Device> = None;
    let mut context: Option<ID3D11DeviceContext> = None;
    let feature_levels = [D3D_FEATURE_LEVEL_11_0];

    D3D11CreateDevice(
        None,
        D3D_DRIVER_TYPE_HARDWARE,
        Default::default(),
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        Some(&feature_levels),
        D3D11_SDK_VERSION,
        Some(&mut device),
        None,
        Some(&mut context),
    )?;

    let device = device.unwrap();
    let context = context.unwrap();

    // Create three swap chains for composition
    let gl_swap_chain = create_swap_chain_for_composition(&device)?;
    let dx_swap_chain = create_swap_chain_for_composition(&device)?;
    let vk_swap_chain = create_swap_chain_for_composition(&device)?;

    // Create render target views
    let (gl_back_buffer, _gl_rtv) = create_rtv(&device, &gl_swap_chain)?;
    let (_dx_back_buffer, dx_rtv) = create_rtv(&device, &dx_swap_chain)?;
    let (vk_back_buffer, _vk_rtv) = create_rtv(&device, &vk_swap_chain)?;

    // Create staging texture for Vulkan panel CPU copy
    let staging_desc = D3D11_TEXTURE2D_DESC {
        Width: PANEL_WIDTH,
        Height: PANEL_HEIGHT,
        MipLevels: 1,
        ArraySize: 1,
        Format: DXGI_FORMAT_B8G8R8A8_UNORM,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        Usage: D3D11_USAGE_STAGING,
        CPUAccessFlags: D3D11_CPU_ACCESS_WRITE.0 as u32,
        ..zeroed()
    };
    let mut vk_staging_tex: Option<ID3D11Texture2D> = None;
    device.CreateTexture2D(&staging_desc, None, Some(&mut vk_staging_tex))?;
    let vk_staging_tex = vk_staging_tex.ok_or_else(|| Error::new(E_FAIL, "CreateTexture2D failed"))?;

    // Compile HLSL shaders for D3D11 panel
    let vs_blob = compile_shader(VS_HLSL, "main", "vs_4_0")?;
    let vs_code =
        std::slice::from_raw_parts(vs_blob.GetBufferPointer() as *const u8, vs_blob.GetBufferSize());
    let mut vs: Option<ID3D11VertexShader> = None;
    device.CreateVertexShader(vs_code, None, Some(&mut vs))?;
    let vs = vs.ok_or_else(|| Error::new(E_FAIL, "CreateVertexShader failed"))?;

    let ps_blob = compile_shader(PS_HLSL, "main", "ps_4_0")?;
    let ps_code =
        std::slice::from_raw_parts(ps_blob.GetBufferPointer() as *const u8, ps_blob.GetBufferSize());
    let mut ps: Option<ID3D11PixelShader> = None;
    device.CreatePixelShader(ps_code, None, Some(&mut ps))?;
    let ps = ps.ok_or_else(|| Error::new(E_FAIL, "CreatePixelShader failed"))?;

    // Input layout
    let layout_desc = [
        D3D11_INPUT_ELEMENT_DESC {
            SemanticName: PCSTR(b"POSITION\0".as_ptr()),
            SemanticIndex: 0,
            Format: DXGI_FORMAT_R32G32B32_FLOAT,
            InputSlot: 0,
            AlignedByteOffset: 0,
            InputSlotClass: D3D11_INPUT_PER_VERTEX_DATA,
            InstanceDataStepRate: 0,
        },
        D3D11_INPUT_ELEMENT_DESC {
            SemanticName: PCSTR(b"COLOR\0".as_ptr()),
            SemanticIndex: 0,
            Format: DXGI_FORMAT_R32G32B32A32_FLOAT,
            InputSlot: 0,
            AlignedByteOffset: 12,
            InputSlotClass: D3D11_INPUT_PER_VERTEX_DATA,
            InstanceDataStepRate: 0,
        },
    ];
    let mut input_layout: Option<ID3D11InputLayout> = None;
    device.CreateInputLayout(&layout_desc, vs_code, Some(&mut input_layout))?;
    let input_layout = input_layout.ok_or_else(|| Error::new(E_FAIL, "CreateInputLayout failed"))?;

    // Vertex buffer (triangle)
    let vertices = [
        Vertex { x:  0.0, y:  0.5, z: 0.5, r: 1.0, g: 0.0, b: 0.0, a: 1.0 },
        Vertex { x:  0.5, y: -0.5, z: 0.5, r: 0.0, g: 1.0, b: 0.0, a: 1.0 },
        Vertex { x: -0.5, y: -0.5, z: 0.5, r: 0.0, g: 0.0, b: 1.0, a: 1.0 },
    ];

    let buf_desc = D3D11_BUFFER_DESC {
        ByteWidth: std::mem::size_of_val(&vertices) as u32,
        Usage: D3D11_USAGE_DEFAULT,
        BindFlags: D3D11_BIND_VERTEX_BUFFER.0 as u32,
        ..zeroed()
    };
    let init_data = D3D11_SUBRESOURCE_DATA {
        pSysMem: vertices.as_ptr() as *const _,
        ..zeroed()
    };
    let mut vertex_buffer: Option<ID3D11Buffer> = None;
    device.CreateBuffer(&buf_desc, Some(&init_data), Some(&mut vertex_buffer))?;
    let vertex_buffer = vertex_buffer.ok_or_else(|| Error::new(E_FAIL, "CreateBuffer failed"))?;

    Ok(D3D11State {
        device,
        context,
        gl_swap_chain,
        gl_back_buffer,
        dx_swap_chain,
        dx_rtv,
        vk_swap_chain,
        vk_back_buffer,
        vk_staging_tex,
        vs,
        ps,
        input_layout,
        vertex_buffer,
    })
}

/// Render the D3D11 panel (center panel): colored triangle
pub unsafe fn render_d3d11_panel(d3d: &D3D11State) {
    let ctx = &d3d.context;

    let vp = D3D11_VIEWPORT {
        Width: PANEL_WIDTH as f32,
        Height: PANEL_HEIGHT as f32,
        MinDepth: 0.0,
        MaxDepth: 1.0,
        ..zeroed()
    };
    ctx.RSSetViewports(Some(&[vp]));

    let rtvs = [Some(d3d.dx_rtv.clone())];
    ctx.OMSetRenderTargets(Some(&rtvs), None);

    let clear_color = [0.05f32, 0.15, 0.05, 1.0]; // greenish background
    ctx.ClearRenderTargetView(&d3d.dx_rtv, &clear_color);

    let stride = std::mem::size_of::<Vertex>() as u32;
    let offset = 0u32;
    ctx.IASetInputLayout(&d3d.input_layout);
    ctx.IASetVertexBuffers(
        0,
        1,
        Some(&Some(d3d.vertex_buffer.clone())),
        Some(&stride),
        Some(&offset),
    );
    ctx.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ctx.VSSetShader(&d3d.vs, None);
    ctx.PSSetShader(&d3d.ps, None);
    ctx.Draw(3, 0);

    let _ = d3d.dx_swap_chain.Present(1, DXGI_PRESENT(0));
}

}

mod opengl {
// OpenGL panel rendering via WGL_NV_DX_interop.
//
// Creates an OpenGL 4.6 core context, registers the D3D11 back buffer
// texture as an OpenGL renderbuffer via WGL_NV_DX_interop, then renders
// a colored triangle into it each frame.
//
// The WGL_NV_DX_interop extension (NVIDIA-only) allows sharing D3D11
// textures with OpenGL without CPU copies.

use crate::d3d11::D3D11State;
use crate::{PANEL_HEIGHT, PANEL_WIDTH};
use std::ffi::CStr;
use std::mem::zeroed;
use std::ptr::null;
use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Dxgi::*,
    Win32::Graphics::Gdi::*,
    Win32::Graphics::OpenGL::*,
    Win32::System::LibraryLoader::*,
};

// OpenGL/WGL constants not in windows crate
const GL_ARRAY_BUFFER: u32 = 0x8892;
const GL_STATIC_DRAW: u32 = 0x88E4;
const GL_FRAGMENT_SHADER: u32 = 0x8B30;
const GL_VERTEX_SHADER: u32 = 0x8B31;
const GL_FRAMEBUFFER: u32 = 0x8D40;
const GL_RENDERBUFFER: u32 = 0x8D41;
const GL_COLOR_ATTACHMENT0: u32 = 0x8CE0;
const GL_FRAMEBUFFER_COMPLETE: u32 = 0x8CD5;
const GL_COMPILE_STATUS: u32 = 0x8B81;
const GL_LINK_STATUS: u32 = 0x8B82;
const WGL_CONTEXT_MAJOR_VERSION_ARB: i32 = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB: i32 = 0x2092;
const WGL_CONTEXT_PROFILE_MASK_ARB: i32 = 0x9126;
const WGL_CONTEXT_CORE_PROFILE_BIT_ARB: i32 = 0x00000001;
const WGL_ACCESS_READ_WRITE_NV: i32 = 0x0001;

type GLsizeiptr = isize;
type GLchar = i8;

// GL function pointer types
type GlGenBuffers = unsafe extern "system" fn(i32, *mut u32);
type GlBindBuffer = unsafe extern "system" fn(u32, u32);
type GlBufferData = unsafe extern "system" fn(u32, GLsizeiptr, *const std::ffi::c_void, u32);
type GlCreateShader = unsafe extern "system" fn(u32) -> u32;
type GlShaderSource = unsafe extern "system" fn(u32, i32, *const *const GLchar, *const i32);
type GlCompileShader = unsafe extern "system" fn(u32);
type GlGetShaderiv = unsafe extern "system" fn(u32, u32, *mut i32);
type GlGetShaderInfoLog = unsafe extern "system" fn(u32, i32, *mut i32, *mut GLchar);
type GlCreateProgram = unsafe extern "system" fn() -> u32;
type GlAttachShader = unsafe extern "system" fn(u32, u32);
type GlLinkProgram = unsafe extern "system" fn(u32);
type GlGetProgramiv = unsafe extern "system" fn(u32, u32, *mut i32);
type GlUseProgram = unsafe extern "system" fn(u32);
type GlGetAttribLocation = unsafe extern "system" fn(u32, *const GLchar) -> i32;
type GlEnableVertexAttribArray = unsafe extern "system" fn(u32);
type GlVertexAttribPointer =
    unsafe extern "system" fn(u32, i32, u32, u8, i32, *const std::ffi::c_void);
type GlGenVertexArrays = unsafe extern "system" fn(i32, *mut u32);
type GlBindVertexArray = unsafe extern "system" fn(u32);
type GlGenFramebuffers = unsafe extern "system" fn(i32, *mut u32);
type GlBindFramebuffer = unsafe extern "system" fn(u32, u32);
type GlFramebufferRenderbuffer = unsafe extern "system" fn(u32, u32, u32, u32);
type GlCheckFramebufferStatus = unsafe extern "system" fn(u32) -> u32;
type GlGenRenderbuffers = unsafe extern "system" fn(i32, *mut u32);
type GlBindRenderbuffer = unsafe extern "system" fn(u32, u32);

// WGL extension function pointer types
type WglCreateContextAttribsARB = unsafe extern "system" fn(HDC, HGLRC, *const i32) -> HGLRC;
type WglDXOpenDeviceNV = unsafe extern "system" fn(*mut std::ffi::c_void) -> HANDLE;
type WglDXCloseDeviceNV = unsafe extern "system" fn(HANDLE) -> BOOL;
type WglDXRegisterObjectNV =
    unsafe extern "system" fn(HANDLE, *mut std::ffi::c_void, u32, u32, i32) -> HANDLE;
type WglDXLockObjectsNV = unsafe extern "system" fn(HANDLE, i32, *mut HANDLE) -> BOOL;
type WglDXUnlockObjectsNV = unsafe extern "system" fn(HANDLE, i32, *mut HANDLE) -> BOOL;

// GLSL shader sources
const VS_GLSL: &[u8] = b"#version 460 core\n\
layout(location=0) in vec3 position;\n\
layout(location=1) in vec3 color;\n\
out vec4 vColor;\n\
void main(){ vColor=vec4(color,1.0); gl_Position=vec4(position.x,-position.y,position.z,1.0); }\n\0";

const PS_GLSL: &[u8] = b"#version 460 core\n\
in vec4 vColor;\n\
out vec4 outColor;\n\
void main(){ outColor=vColor; }\n\0";

/// OpenGL state for the left panel
pub struct OpenGLState {
    hdc: HDC,
    hglrc: HGLRC,
    program: u32,
    vbo: [u32; 2],
    fbo: u32,
    pos_attrib: i32,
    col_attrib: i32,
    interop_device: HANDLE,
    interop_object: HANDLE,

    // GL function pointers
    gl_bind_framebuffer: GlBindFramebuffer,
    gl_use_program: GlUseProgram,
    gl_bind_buffer: GlBindBuffer,
    gl_vertex_attrib_pointer: GlVertexAttribPointer,
    wgl_dx_lock_objects: WglDXLockObjectsNV,
    wgl_dx_unlock_objects: WglDXUnlockObjectsNV,
}

/// Resolve a GL/WGL extension function by name
unsafe fn get_gl_proc(name: &[u8]) -> *const std::ffi::c_void {
    let name_cstr = PCSTR(name.as_ptr());
    let p = wglGetProcAddress(name_cstr);
    match p {
        Some(f) => f as *const std::ffi::c_void,
        None => {
            let module = GetModuleHandleA(s!("opengl32.dll")).unwrap_or_default();
            if !module.is_invalid() {
                GetProcAddress(module, name_cstr)
                    .map(|f| f as *const std::ffi::c_void)
                    .unwrap_or(null())
            } else {
                null()
            }
        }
    }
}

/// Load a GL function pointer, returning error if not found
macro_rules! load_gl {
    ($name:expr, $ty:ty) => {{
        let p = get_gl_proc($name);
        if p.is_null() {
            return Err(Error::new(
                E_FAIL,
                format!(
                    "Missing GL function: {}",
                    String::from_utf8_lossy(&$name[..$name.len() - 1])
                ),
            ));
        }
        std::mem::transmute::<_, $ty>(p)
    }};
}

/// Create an OpenGL 4.6 core context via WGL
unsafe fn enable_opengl(hdc: HDC) -> Result<HGLRC> {
    let mut pfd: PIXELFORMATDESCRIPTOR = zeroed();
    pfd.nSize = std::mem::size_of::<PIXELFORMATDESCRIPTOR>() as u16;
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 32;
    pfd.cDepthBits = 24;
    pfd.iLayerType = PFD_MAIN_PLANE.0 as u8;

    let pf = ChoosePixelFormat(hdc, &pfd);
    if pf == 0 {
        return Err(Error::new(E_FAIL, "ChoosePixelFormat failed"));
    }
    let _ = SetPixelFormat(hdc, pf, &pfd);

    // Create legacy context first to bootstrap wglCreateContextAttribsARB
    let old_rc = wglCreateContext(hdc)?;
    wglMakeCurrent(hdc, old_rc)?;

    let p_create = get_gl_proc(b"wglCreateContextAttribsARB\0");
    if p_create.is_null() {
        return Ok(old_rc); // fallback to legacy context
    }
    let wgl_create: WglCreateContextAttribsARB = std::mem::transmute(p_create);

    let attrs: [i32; 7] = [
        WGL_CONTEXT_MAJOR_VERSION_ARB,
        4,
        WGL_CONTEXT_MINOR_VERSION_ARB,
        6,
        WGL_CONTEXT_PROFILE_MASK_ARB,
        WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
        0,
    ];

    let rc = wgl_create(hdc, HGLRC::default(), attrs.as_ptr());
    if rc.is_invalid() {
        return Ok(old_rc); // fallback
    }

    wglMakeCurrent(hdc, rc)?;
    wglDeleteContext(old_rc)?;
    Ok(rc)
}

/// Initialize OpenGL for the composition pipeline
pub unsafe fn init_opengl(hwnd: HWND, d3d: &D3D11State) -> Result<OpenGLState> {
    let hdc = GetDC(Some(hwnd));
    if hdc.is_invalid() {
        return Err(Error::new(E_FAIL, "GetDC failed"));
    }

    let hglrc = enable_opengl(hdc)?;
    wglMakeCurrent(hdc, hglrc)?;

    // Load all required GL extension functions
    let gl_gen_buffers: GlGenBuffers = load_gl!(b"glGenBuffers\0", GlGenBuffers);
    let gl_bind_buffer: GlBindBuffer = load_gl!(b"glBindBuffer\0", GlBindBuffer);
    let gl_buffer_data: GlBufferData = load_gl!(b"glBufferData\0", GlBufferData);
    let gl_create_shader: GlCreateShader = load_gl!(b"glCreateShader\0", GlCreateShader);
    let gl_shader_source: GlShaderSource = load_gl!(b"glShaderSource\0", GlShaderSource);
    let gl_compile_shader: GlCompileShader = load_gl!(b"glCompileShader\0", GlCompileShader);
    let gl_get_shaderiv: GlGetShaderiv = load_gl!(b"glGetShaderiv\0", GlGetShaderiv);
    let gl_get_shader_info_log: GlGetShaderInfoLog =
        load_gl!(b"glGetShaderInfoLog\0", GlGetShaderInfoLog);
    let gl_create_program: GlCreateProgram = load_gl!(b"glCreateProgram\0", GlCreateProgram);
    let gl_attach_shader: GlAttachShader = load_gl!(b"glAttachShader\0", GlAttachShader);
    let gl_link_program: GlLinkProgram = load_gl!(b"glLinkProgram\0", GlLinkProgram);
    let gl_get_programiv: GlGetProgramiv = load_gl!(b"glGetProgramiv\0", GlGetProgramiv);
    let gl_use_program: GlUseProgram = load_gl!(b"glUseProgram\0", GlUseProgram);
    let gl_get_attrib_location: GlGetAttribLocation =
        load_gl!(b"glGetAttribLocation\0", GlGetAttribLocation);
    let gl_enable_vertex_attrib_array: GlEnableVertexAttribArray =
        load_gl!(b"glEnableVertexAttribArray\0", GlEnableVertexAttribArray);
    let gl_vertex_attrib_pointer: GlVertexAttribPointer =
        load_gl!(b"glVertexAttribPointer\0", GlVertexAttribPointer);
    let gl_gen_vertex_arrays: GlGenVertexArrays =
        load_gl!(b"glGenVertexArrays\0", GlGenVertexArrays);
    let gl_bind_vertex_array: GlBindVertexArray =
        load_gl!(b"glBindVertexArray\0", GlBindVertexArray);
    let gl_gen_framebuffers: GlGenFramebuffers =
        load_gl!(b"glGenFramebuffers\0", GlGenFramebuffers);
    let gl_bind_framebuffer: GlBindFramebuffer =
        load_gl!(b"glBindFramebuffer\0", GlBindFramebuffer);
    let gl_framebuffer_renderbuffer: GlFramebufferRenderbuffer =
        load_gl!(b"glFramebufferRenderbuffer\0", GlFramebufferRenderbuffer);
    let gl_check_framebuffer_status: GlCheckFramebufferStatus =
        load_gl!(b"glCheckFramebufferStatus\0", GlCheckFramebufferStatus);
    let gl_gen_renderbuffers: GlGenRenderbuffers =
        load_gl!(b"glGenRenderbuffers\0", GlGenRenderbuffers);
    let gl_bind_renderbuffer: GlBindRenderbuffer =
        load_gl!(b"glBindRenderbuffer\0", GlBindRenderbuffer);

    // WGL_NV_DX_interop extension functions
    let wgl_dx_open_device: WglDXOpenDeviceNV =
        load_gl!(b"wglDXOpenDeviceNV\0", WglDXOpenDeviceNV);
    let _wgl_dx_close_device: WglDXCloseDeviceNV =
        load_gl!(b"wglDXCloseDeviceNV\0", WglDXCloseDeviceNV);
    let wgl_dx_register_object: WglDXRegisterObjectNV =
        load_gl!(b"wglDXRegisterObjectNV\0", WglDXRegisterObjectNV);
    let wgl_dx_lock_objects: WglDXLockObjectsNV =
        load_gl!(b"wglDXLockObjectsNV\0", WglDXLockObjectsNV);
    let wgl_dx_unlock_objects: WglDXUnlockObjectsNV =
        load_gl!(b"wglDXUnlockObjectsNV\0", WglDXUnlockObjectsNV);

    // Open D3D11 device for interop
    let d3d_raw = std::mem::transmute_copy::<_, *mut std::ffi::c_void>(&d3d.device);
    let interop_device = wgl_dx_open_device(d3d_raw);
    if interop_device.is_invalid() {
        return Err(Error::new(E_FAIL, "wglDXOpenDeviceNV failed"));
    }

    // Create GL renderbuffer and register D3D11 back buffer via NV interop
    let mut rbo: u32 = 0;
    gl_gen_renderbuffers(1, &mut rbo);
    gl_bind_renderbuffer(GL_RENDERBUFFER, rbo);

    let bb_raw = std::mem::transmute_copy::<_, *mut std::ffi::c_void>(&d3d.gl_back_buffer);
    let interop_object = wgl_dx_register_object(
        interop_device,
        bb_raw,
        rbo,
        GL_RENDERBUFFER,
        WGL_ACCESS_READ_WRITE_NV,
    );
    if interop_object.is_invalid() {
        return Err(Error::new(E_FAIL, "wglDXRegisterObjectNV failed"));
    }

    // Create FBO targeting the interop renderbuffer
    let mut fbo: u32 = 0;
    gl_gen_framebuffers(1, &mut fbo);
    gl_bind_framebuffer(GL_FRAMEBUFFER, fbo);
    gl_framebuffer_renderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rbo);
    let fbo_status = gl_check_framebuffer_status(GL_FRAMEBUFFER);
    gl_bind_framebuffer(GL_FRAMEBUFFER, 0);
    if fbo_status != GL_FRAMEBUFFER_COMPLETE {
        return Err(Error::new(
            E_FAIL, format!("FBO incomplete: 0x{:04X}", fbo_status),
        ));
    }

    // Create VAO and VBOs for the triangle
    let mut vao: u32 = 0;
    gl_gen_vertex_arrays(1, &mut vao);
    gl_bind_vertex_array(vao);

    let mut vbo = [0u32; 2];
    gl_gen_buffers(2, vbo.as_mut_ptr());

    // Position VBO
    let positions: [f32; 9] = [-0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0];
    gl_bind_buffer(GL_ARRAY_BUFFER, vbo[0]);
    gl_buffer_data(
        GL_ARRAY_BUFFER,
        std::mem::size_of_val(&positions) as GLsizeiptr,
        positions.as_ptr() as *const _,
        GL_STATIC_DRAW,
    );

    // Color VBO (BGR to match C version)
    let colors: [f32; 9] = [0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0];
    gl_bind_buffer(GL_ARRAY_BUFFER, vbo[1]);
    gl_buffer_data(
        GL_ARRAY_BUFFER,
        std::mem::size_of_val(&colors) as GLsizeiptr,
        colors.as_ptr() as *const _,
        GL_STATIC_DRAW,
    );

    // Compile and link GL shaders
    let compile_gl_shader = |shader_type: u32, source: &[u8]| -> Result<u32> {
        let shader = gl_create_shader(shader_type);
        let src_ptr = source.as_ptr() as *const GLchar;
        gl_shader_source(shader, 1, &src_ptr, null());
        gl_compile_shader(shader);
        let mut ok: i32 = 0;
        gl_get_shaderiv(shader, GL_COMPILE_STATUS, &mut ok);
        if ok == 0 {
            let mut log = [0i8; 1024];
            let mut len: i32 = 0;
            gl_get_shader_info_log(shader, 1024, &mut len, log.as_mut_ptr());
            let msg = CStr::from_ptr(log.as_ptr()).to_string_lossy();
            return Err(Error::new(E_FAIL, msg.as_ref()));
        }
        Ok(shader)
    };

    let vs = compile_gl_shader(GL_VERTEX_SHADER, VS_GLSL)?;
    let fs = compile_gl_shader(GL_FRAGMENT_SHADER, PS_GLSL)?;

    let program = gl_create_program();
    gl_attach_shader(program, vs);
    gl_attach_shader(program, fs);
    gl_link_program(program);

    let mut link_ok: i32 = 0;
    gl_get_programiv(program, GL_LINK_STATUS, &mut link_ok);
    if link_ok == 0 {
        return Err(Error::new(E_FAIL, "GL program link failed"));
    }

    gl_use_program(program);
    let pos_attrib = gl_get_attrib_location(program, b"position\0".as_ptr() as *const GLchar);
    let col_attrib = gl_get_attrib_location(program, b"color\0".as_ptr() as *const GLchar);
    if pos_attrib < 0 || col_attrib < 0 {
        return Err(Error::new(E_FAIL, "GL attrib location lookup failed"));
    }
    gl_enable_vertex_attrib_array(pos_attrib as u32);
    gl_enable_vertex_attrib_array(col_attrib as u32);

    Ok(OpenGLState {
        hdc,
        hglrc,
        program,
        vbo,
        fbo,
        pos_attrib,
        col_attrib,
        interop_device,
        interop_object,
        gl_bind_framebuffer,
        gl_use_program,
        gl_bind_buffer,
        gl_vertex_attrib_pointer,
        wgl_dx_lock_objects,
        wgl_dx_unlock_objects,
    })
}

/// Render the OpenGL triangle into the D3D11 swap chain via NV interop
pub unsafe fn render_opengl_panel(gl: &OpenGLState, d3d: &D3D11State) {
    if gl.hglrc.is_invalid() || gl.interop_device.is_invalid() {
        return;
    }

    let _ = wglMakeCurrent(gl.hdc, gl.hglrc);

    // Lock the interop object for GL access
    let mut objs = [gl.interop_object];
    if !(gl.wgl_dx_lock_objects)(gl.interop_device, 1, objs.as_mut_ptr()).as_bool() {
        return;
    }

    // Render to FBO
    (gl.gl_bind_framebuffer)(GL_FRAMEBUFFER, gl.fbo);
    glViewport(0, 0, PANEL_WIDTH as i32, PANEL_HEIGHT as i32);
    glClearColor(0.05, 0.05, 0.15, 1.0); // dark blue background
    glClear(GL_COLOR_BUFFER_BIT);

    (gl.gl_use_program)(gl.program);
    (gl.gl_bind_buffer)(GL_ARRAY_BUFFER, gl.vbo[0]);
    (gl.gl_vertex_attrib_pointer)(gl.pos_attrib as u32, 3, GL_FLOAT, 0, 0, null());
    (gl.gl_bind_buffer)(GL_ARRAY_BUFFER, gl.vbo[1]);
    (gl.gl_vertex_attrib_pointer)(gl.col_attrib as u32, 3, GL_FLOAT, 0, 0, null());
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glFlush();
    (gl.gl_bind_framebuffer)(GL_FRAMEBUFFER, 0);

    // Unlock interop object
    let _ = (gl.wgl_dx_unlock_objects)(gl.interop_device, 1, objs.as_mut_ptr());

    // Present OpenGL panel swap chain
    let _ = d3d.gl_swap_chain.Present(1, DXGI_PRESENT(0));
}

}

mod vulkan_panel {
// Vulkan offscreen panel rendering.
//
// Renders a triangle offscreen using Vulkan, then reads back the pixel data
// via a host-visible buffer and copies it into a D3D11 staging texture,
// which is then copied to the Vulkan panel's swap chain back buffer.
//
// This approach works on any Vulkan-capable GPU (no vendor-specific interop).
// The readback path is: Vulkan image -> Vulkan buffer -> CPU -> D3D11 staging -> D3D11 back buffer.
//
// Prerequisites:
//   - Vulkan runtime installed
//   - SPIR-V shaders compiled from hello.vert / hello.frag:
//       glslangValidator -V hello.vert -o hello_vert.spv
//       glslangValidator -V hello.frag -o hello_frag.spv

use crate::d3d11::D3D11State;
use crate::{PANEL_HEIGHT, PANEL_WIDTH};
use ash::vk;
use std::ffi::CStr;
use std::mem::zeroed;
use windows::{
    core::*,
    Win32::Foundation::E_FAIL,
    Win32::Graphics::Direct3D11::*,
    Win32::Graphics::Dxgi::*,
};

/// Vulkan state for offscreen rendering
pub struct VulkanState {
    _entry: ash::Entry,
    instance: ash::Instance,
    device: ash::Device,
    queue: vk::Queue,
    off_image: vk::Image,
    off_memory: vk::DeviceMemory,
    off_view: vk::ImageView,
    readback_buf: vk::Buffer,
    readback_mem: vk::DeviceMemory,
    render_pass: vk::RenderPass,
    framebuffer: vk::Framebuffer,
    pipeline_layout: vk::PipelineLayout,
    pipeline: vk::Pipeline,
    cmd_pool: vk::CommandPool,
    cmd_buf: vk::CommandBuffer,
    fence: vk::Fence,
}

impl Drop for VulkanState {
    fn drop(&mut self) {
        unsafe {
            let _ = self.device.device_wait_idle();
            self.device.destroy_fence(self.fence, None);
            self.device.destroy_command_pool(self.cmd_pool, None);
            self.device.destroy_pipeline(self.pipeline, None);
            self.device
                .destroy_pipeline_layout(self.pipeline_layout, None);
            self.device.destroy_framebuffer(self.framebuffer, None);
            self.device.destroy_render_pass(self.render_pass, None);
            self.device.destroy_image_view(self.off_view, None);
            self.device.destroy_image(self.off_image, None);
            self.device.free_memory(self.off_memory, None);
            self.device.destroy_buffer(self.readback_buf, None);
            self.device.free_memory(self.readback_mem, None);
            self.device.destroy_device(None);
            self.instance.destroy_instance(None);
        }
    }
}

/// Find a memory type index that satisfies the given requirements
unsafe fn find_memory_type(
    instance: &ash::Instance,
    phys_dev: vk::PhysicalDevice,
    type_bits: u32,
    props: vk::MemoryPropertyFlags,
) -> Option<u32> {
    let mem_props = instance.get_physical_device_memory_properties(phys_dev);
    for i in 0..mem_props.memory_type_count {
        if (type_bits & (1 << i)) != 0
            && mem_props.memory_types[i as usize]
                .property_flags
                .contains(props)
        {
            return Some(i);
        }
    }
    None
}

/// Read a binary SPIR-V file and return as Vec<u32>
fn read_spirv_file(path: &str) -> Result<Vec<u32>> {
    let data = std::fs::read(path).map_err(|e| {
        Error::new(
            E_FAIL, format!("Failed to read {}: {}", path, e),
        )
    })?;
    if data.len() % 4 != 0 {
        return Err(Error::new(E_FAIL, "SPIR-V file size not aligned to 4"));
    }
    let words: Vec<u32> = data
        .chunks_exact(4)
        .map(|c| u32::from_le_bytes([c[0], c[1], c[2], c[3]]))
        .collect();
    Ok(words)
}

/// Initialize Vulkan for offscreen rendering
pub unsafe fn init_vulkan(_d3d: &D3D11State) -> Result<VulkanState> {
    let entry = ash::Entry::linked();

    // Create Vulkan instance
    let app_info = vk::ApplicationInfo::default()
        .application_name(CStr::from_bytes_with_nul_unchecked(
            b"composition_triangle_vk\0",
        ))
        .api_version(vk::make_api_version(0, 1, 3, 0));

    let create_info = vk::InstanceCreateInfo::default().application_info(&app_info);

    let instance = entry
        .create_instance(&create_info, None)
        .map_err(|e| Error::new(E_FAIL, format!("vkCreateInstance: {:?}", e)))?;

    // Pick a physical device with a graphics queue
    let phys_devs = instance
        .enumerate_physical_devices()
        .map_err(|e| Error::new(E_FAIL, format!("enumerate_physical_devices: {:?}", e)))?;

    let mut phys_dev = vk::PhysicalDevice::null();
    let mut queue_family: u32 = u32::MAX;

    for pd in &phys_devs {
        let qf_props = instance.get_physical_device_queue_family_properties(*pd);
        for (i, qf) in qf_props.iter().enumerate() {
            if qf.queue_flags.contains(vk::QueueFlags::GRAPHICS) {
                phys_dev = *pd;
                queue_family = i as u32;
                break;
            }
        }
        if queue_family != u32::MAX {
            break;
        }
    }
    if phys_dev == vk::PhysicalDevice::null() {
        return Err(Error::new(E_FAIL, "No Vulkan GPU with graphics queue"));
    }

    // Create logical device and queue
    let prio = [1.0f32];
    let queue_ci = vk::DeviceQueueCreateInfo::default()
        .queue_family_index(queue_family)
        .queue_priorities(&prio);

    let device_ci = vk::DeviceCreateInfo::default().queue_create_infos(std::slice::from_ref(&queue_ci));

    let device = instance
        .create_device(phys_dev, &device_ci, None)
        .map_err(|e| Error::new(E_FAIL, format!("vkCreateDevice: {:?}", e)))?;

    let queue = device.get_device_queue(queue_family, 0);

    // Create offscreen image (BGRA8, optimal tiling)
    let img_ci = vk::ImageCreateInfo::default()
        .image_type(vk::ImageType::TYPE_2D)
        .format(vk::Format::B8G8R8A8_UNORM)
        .extent(vk::Extent3D {
            width: PANEL_WIDTH,
            height: PANEL_HEIGHT,
            depth: 1,
        })
        .mip_levels(1)
        .array_layers(1)
        .samples(vk::SampleCountFlags::TYPE_1)
        .tiling(vk::ImageTiling::OPTIMAL)
        .usage(vk::ImageUsageFlags::COLOR_ATTACHMENT | vk::ImageUsageFlags::TRANSFER_SRC)
        .initial_layout(vk::ImageLayout::UNDEFINED);

    let off_image = device.create_image(&img_ci, None).map_err(|e| {
        Error::new(E_FAIL, format!("vkCreateImage: {:?}", e))
    })?;

    let mem_req = device.get_image_memory_requirements(off_image);
    let mem_type = find_memory_type(
        &instance,
        phys_dev,
        mem_req.memory_type_bits,
        vk::MemoryPropertyFlags::DEVICE_LOCAL,
    )
    .ok_or_else(|| Error::new(E_FAIL, "No suitable memory type for image"))?;

    let alloc_info = vk::MemoryAllocateInfo::default()
        .allocation_size(mem_req.size)
        .memory_type_index(mem_type);

    let off_memory = device.allocate_memory(&alloc_info, None).map_err(|e| {
        Error::new(E_FAIL, format!("vkAllocateMemory: {:?}", e))
    })?;
    device
        .bind_image_memory(off_image, off_memory, 0)
        .map_err(|e| Error::new(E_FAIL, format!("bind_image_memory: {:?}", e)))?;

    // Image view
    let iv_ci = vk::ImageViewCreateInfo::default()
        .image(off_image)
        .view_type(vk::ImageViewType::TYPE_2D)
        .format(vk::Format::B8G8R8A8_UNORM)
        .subresource_range(vk::ImageSubresourceRange {
            aspect_mask: vk::ImageAspectFlags::COLOR,
            base_mip_level: 0,
            level_count: 1,
            base_array_layer: 0,
            layer_count: 1,
        });

    let off_view = device.create_image_view(&iv_ci, None).map_err(|e| {
        Error::new(E_FAIL, format!("vkCreateImageView: {:?}", e))
    })?;

    // Readback buffer (host-visible, for copying rendered pixels to CPU)
    let buf_size = (PANEL_WIDTH * PANEL_HEIGHT * 4) as vk::DeviceSize;
    let buf_ci = vk::BufferCreateInfo::default()
        .size(buf_size)
        .usage(vk::BufferUsageFlags::TRANSFER_DST);

    let readback_buf = device.create_buffer(&buf_ci, None).map_err(|e| {
        Error::new(E_FAIL, format!("vkCreateBuffer: {:?}", e))
    })?;

    let buf_mem_req = device.get_buffer_memory_requirements(readback_buf);
    let buf_mem_type = find_memory_type(
        &instance,
        phys_dev,
        buf_mem_req.memory_type_bits,
        vk::MemoryPropertyFlags::HOST_VISIBLE | vk::MemoryPropertyFlags::HOST_COHERENT,
    )
    .ok_or_else(|| Error::new(E_FAIL, "No host-visible memory type"))?;

    let buf_alloc = vk::MemoryAllocateInfo::default()
        .allocation_size(buf_mem_req.size)
        .memory_type_index(buf_mem_type);

    let readback_mem = device.allocate_memory(&buf_alloc, None).map_err(|e| {
        Error::new(
            E_FAIL,
            format!("vkAllocateMemory(readback): {:?}", e),
        )
    })?;
    device.bind_buffer_memory(readback_buf, readback_mem, 0).unwrap();

    // Render pass
    let att = vk::AttachmentDescription::default()
        .format(vk::Format::B8G8R8A8_UNORM)
        .samples(vk::SampleCountFlags::TYPE_1)
        .load_op(vk::AttachmentLoadOp::CLEAR)
        .store_op(vk::AttachmentStoreOp::STORE)
        .stencil_load_op(vk::AttachmentLoadOp::DONT_CARE)
        .stencil_store_op(vk::AttachmentStoreOp::DONT_CARE)
        .initial_layout(vk::ImageLayout::UNDEFINED)
        .final_layout(vk::ImageLayout::TRANSFER_SRC_OPTIMAL);

    let att_ref = vk::AttachmentReference {
        attachment: 0,
        layout: vk::ImageLayout::COLOR_ATTACHMENT_OPTIMAL,
    };
    let subpass = vk::SubpassDescription::default()
        .pipeline_bind_point(vk::PipelineBindPoint::GRAPHICS)
        .color_attachments(std::slice::from_ref(&att_ref));

    let rp_ci = vk::RenderPassCreateInfo::default()
        .attachments(std::slice::from_ref(&att))
        .subpasses(std::slice::from_ref(&subpass));

    let render_pass = device.create_render_pass(&rp_ci, None).map_err(|e| {
        Error::new(
            E_FAIL, format!("vkCreateRenderPass: {:?}", e),
        )
    })?;

    // Framebuffer
    let fb_ci = vk::FramebufferCreateInfo::default()
        .render_pass(render_pass)
        .attachments(std::slice::from_ref(&off_view))
        .width(PANEL_WIDTH)
        .height(PANEL_HEIGHT)
        .layers(1);

    let framebuffer = device.create_framebuffer(&fb_ci, None).map_err(|e| {
        Error::new(
            E_FAIL, format!("vkCreateFramebuffer: {:?}", e),
        )
    })?;

    // Load SPIR-V shaders
    let vs_spv = read_spirv_file("hello_vert.spv")?;
    let fs_spv = read_spirv_file("hello_frag.spv")?;

    let vs_ci = vk::ShaderModuleCreateInfo::default().code(&vs_spv);
    let fs_ci = vk::ShaderModuleCreateInfo::default().code(&fs_spv);

    let vs_mod = device.create_shader_module(&vs_ci, None).unwrap();
    let fs_mod = device.create_shader_module(&fs_ci, None).unwrap();

    let entry_name = CStr::from_bytes_with_nul_unchecked(b"main\0");
    let stages = [
        vk::PipelineShaderStageCreateInfo::default()
            .stage(vk::ShaderStageFlags::VERTEX)
            .module(vs_mod)
            .name(entry_name),
        vk::PipelineShaderStageCreateInfo::default()
            .stage(vk::ShaderStageFlags::FRAGMENT)
            .module(fs_mod)
            .name(entry_name),
    ];

    // Pipeline (no vertex input - vertices are hardcoded in the shader)
    let vertex_input = vk::PipelineVertexInputStateCreateInfo::default();
    let input_assembly = vk::PipelineInputAssemblyStateCreateInfo::default()
        .topology(vk::PrimitiveTopology::TRIANGLE_LIST);

    let viewport = vk::Viewport {
        x: 0.0,
        y: 0.0,
        width: PANEL_WIDTH as f32,
        height: PANEL_HEIGHT as f32,
        min_depth: 0.0,
        max_depth: 1.0,
    };
    let scissor = vk::Rect2D {
        offset: vk::Offset2D { x: 0, y: 0 },
        extent: vk::Extent2D {
            width: PANEL_WIDTH,
            height: PANEL_HEIGHT,
        },
    };
    let viewport_state = vk::PipelineViewportStateCreateInfo::default()
        .viewports(std::slice::from_ref(&viewport))
        .scissors(std::slice::from_ref(&scissor));

    let rasterizer = vk::PipelineRasterizationStateCreateInfo::default()
        .polygon_mode(vk::PolygonMode::FILL)
        .line_width(1.0)
        .cull_mode(vk::CullModeFlags::BACK)
        .front_face(vk::FrontFace::CLOCKWISE);

    let multisampling =
        vk::PipelineMultisampleStateCreateInfo::default().rasterization_samples(vk::SampleCountFlags::TYPE_1);

    let color_blend_attachment = vk::PipelineColorBlendAttachmentState::default()
        .color_write_mask(vk::ColorComponentFlags::RGBA);
    let color_blending = vk::PipelineColorBlendStateCreateInfo::default()
        .attachments(std::slice::from_ref(&color_blend_attachment));

    let layout_ci = vk::PipelineLayoutCreateInfo::default();
    let pipeline_layout = device
        .create_pipeline_layout(&layout_ci, None)
        .map_err(|e| {
            Error::new(
                E_FAIL, format!("vkCreatePipelineLayout: {:?}", e),
            )
        })?;

    let gp_ci = vk::GraphicsPipelineCreateInfo::default()
        .stages(&stages)
        .vertex_input_state(&vertex_input)
        .input_assembly_state(&input_assembly)
        .viewport_state(&viewport_state)
        .rasterization_state(&rasterizer)
        .multisample_state(&multisampling)
        .color_blend_state(&color_blending)
        .layout(pipeline_layout)
        .render_pass(render_pass)
        .subpass(0);

    let pipeline = device
        .create_graphics_pipelines(vk::PipelineCache::null(), &[gp_ci], None)
        .map_err(|(_pipelines, e)| {
            Error::new(
                E_FAIL, format!("vkCreateGraphicsPipelines: {:?}", e),
            )
        })?[0];

    // Cleanup shader modules (no longer needed after pipeline creation)
    device.destroy_shader_module(vs_mod, None);
    device.destroy_shader_module(fs_mod, None);

    // Command pool and buffer
    let cp_ci = vk::CommandPoolCreateInfo::default()
        .flags(vk::CommandPoolCreateFlags::RESET_COMMAND_BUFFER)
        .queue_family_index(queue_family);
    let cmd_pool = device.create_command_pool(&cp_ci, None).unwrap();

    let cb_ai = vk::CommandBufferAllocateInfo::default()
        .command_pool(cmd_pool)
        .level(vk::CommandBufferLevel::PRIMARY)
        .command_buffer_count(1);
    let cmd_bufs = device.allocate_command_buffers(&cb_ai).unwrap();
    let cmd_buf = cmd_bufs[0];

    // Fence (signaled initially)
    let fence_ci =
        vk::FenceCreateInfo::default().flags(vk::FenceCreateFlags::SIGNALED);
    let fence = device.create_fence(&fence_ci, None).unwrap();

    Ok(VulkanState {
        _entry: entry,
        instance,
        device,
        queue,
        off_image,
        off_memory,
        off_view,
        readback_buf,
        readback_mem,
        render_pass,
        framebuffer,
        pipeline_layout,
        pipeline,
        cmd_pool,
        cmd_buf,
        fence,
    })
}

/// Render a Vulkan triangle offscreen and copy pixels to the D3D11 swap chain
pub unsafe fn render_vulkan_panel(vk_state: &VulkanState, d3d: &D3D11State) {
    let device = &vk_state.device;

    // Wait for previous frame's fence
    let _ = device.wait_for_fences(&[vk_state.fence], true, u64::MAX);
    let _ = device.reset_fences(&[vk_state.fence]);
    let _ = device.reset_command_buffer(vk_state.cmd_buf, vk::CommandBufferResetFlags::empty());

    // Record command buffer
    let begin_info = vk::CommandBufferBeginInfo::default();
    device
        .begin_command_buffer(vk_state.cmd_buf, &begin_info)
        .unwrap();

    let clear_value = vk::ClearValue {
        color: vk::ClearColorValue {
            float32: [0.15, 0.05, 0.05, 1.0], // reddish background
        },
    };
    let rp_begin = vk::RenderPassBeginInfo::default()
        .render_pass(vk_state.render_pass)
        .framebuffer(vk_state.framebuffer)
        .render_area(vk::Rect2D {
            offset: vk::Offset2D { x: 0, y: 0 },
            extent: vk::Extent2D {
                width: PANEL_WIDTH,
                height: PANEL_HEIGHT,
            },
        })
        .clear_values(std::slice::from_ref(&clear_value));

    device.cmd_begin_render_pass(vk_state.cmd_buf, &rp_begin, vk::SubpassContents::INLINE);
    device.cmd_bind_pipeline(
        vk_state.cmd_buf,
        vk::PipelineBindPoint::GRAPHICS,
        vk_state.pipeline,
    );
    device.cmd_draw(vk_state.cmd_buf, 3, 1, 0, 0);
    device.cmd_end_render_pass(vk_state.cmd_buf);

    // Copy image to readback buffer
    let region = vk::BufferImageCopy {
        buffer_offset: 0,
        buffer_row_length: PANEL_WIDTH,
        buffer_image_height: PANEL_HEIGHT,
        image_subresource: vk::ImageSubresourceLayers {
            aspect_mask: vk::ImageAspectFlags::COLOR,
            mip_level: 0,
            base_array_layer: 0,
            layer_count: 1,
        },
        image_offset: vk::Offset3D { x: 0, y: 0, z: 0 },
        image_extent: vk::Extent3D {
            width: PANEL_WIDTH,
            height: PANEL_HEIGHT,
            depth: 1,
        },
    };
    device.cmd_copy_image_to_buffer(
        vk_state.cmd_buf,
        vk_state.off_image,
        vk::ImageLayout::TRANSFER_SRC_OPTIMAL,
        vk_state.readback_buf,
        &[region],
    );

    device.end_command_buffer(vk_state.cmd_buf).unwrap();

    // Submit and wait
    let submit_info =
        vk::SubmitInfo::default().command_buffers(std::slice::from_ref(&vk_state.cmd_buf));
    device
        .queue_submit(vk_state.queue, &[submit_info], vk_state.fence)
        .unwrap();
    let _ = device.wait_for_fences(&[vk_state.fence], true, u64::MAX);

    // Map readback buffer and copy to D3D11 staging texture
    let vk_data = device
        .map_memory(
            vk_state.readback_mem,
            0,
            (PANEL_WIDTH * PANEL_HEIGHT * 4) as vk::DeviceSize,
            vk::MemoryMapFlags::empty(),
        )
        .unwrap();

    let ctx = &d3d.context;
    let mut mapped: D3D11_MAPPED_SUBRESOURCE = zeroed();
    let hr = ctx.Map(
        &d3d.vk_staging_tex,
        0,
        D3D11_MAP_WRITE,
        0,
        Some(&mut mapped),
    );
    if hr.is_ok() {
        let src = vk_data as *const u8;
        let dst = mapped.pData as *mut u8;
        let pitch = PANEL_WIDTH * 4;

        for y in 0..PANEL_HEIGHT {
            std::ptr::copy_nonoverlapping(
                src.add((y * pitch) as usize),
                dst.add((y * mapped.RowPitch) as usize),
                pitch as usize,
            );
        }

        ctx.Unmap(&d3d.vk_staging_tex, 0);
        ctx.CopyResource(&d3d.vk_back_buffer, &d3d.vk_staging_tex);
    }

    device.unmap_memory(vk_state.readback_mem);

    // Present Vulkan panel swap chain
    let _ = d3d.vk_swap_chain.Present(1, DXGI_PRESENT(0));
}

}



