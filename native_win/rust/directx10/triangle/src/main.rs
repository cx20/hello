use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Direct3D::Fxc::*,
    Win32::Graphics::Direct3D::*,
    Win32::Graphics::Direct3D10::*,
    Win32::Graphics::Dxgi::Common::*,
    Win32::Graphics::Dxgi::*,
    Win32::System::LibraryLoader::*,
    Win32::UI::WindowsAndMessaging::*,
};

use std::mem;

const SHADER_SOURCE: &str = r#"
struct VS_INPUT {
    float3 pos : POSITION;
    float4 col : COLOR;
};

struct PS_INPUT {
    float4 pos : SV_POSITION;
    float4 col : COLOR;
};

PS_INPUT VSMain(VS_INPUT input) {
    PS_INPUT output;
    output.pos = float4(input.pos, 1.0);
    output.col = input.col;
    return output;
}

float4 PSMain(PS_INPUT input) : SV_Target {
    return input.col;
}
"#;

#[repr(C)]
struct Vertex {
    position: [f32; 3],
    color: [f32; 4],
}

// D3D10 App - no DeviceContext (device handles rendering directly)
struct D3D10App {
    device: ID3D10Device,
    swap_chain: IDXGISwapChain,
    render_target_view: ID3D10RenderTargetView,
    vertex_buffer: ID3D10Buffer,
    input_layout: ID3D10InputLayout,
    vertex_shader: ID3D10VertexShader,
    pixel_shader: ID3D10PixelShader,
}

impl D3D10App {
    fn new(hwnd: HWND) -> Result<Self> {
        unsafe {
            let mut device: Option<ID3D10Device> = None;
            let mut swap_chain: Option<IDXGISwapChain> = None;

            let sc_desc = DXGI_SWAP_CHAIN_DESC {
                BufferDesc: DXGI_MODE_DESC {
                    Width: 640,
                    Height: 480,
                    RefreshRate: DXGI_RATIONAL { Numerator: 60, Denominator: 1 },
                    Format: DXGI_FORMAT_R8G8B8A8_UNORM,
                    ..Default::default()
                },
                SampleDesc: DXGI_SAMPLE_DESC { Count: 1, Quality: 0 },
                BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
                BufferCount: 1,
                OutputWindow: hwnd,
                Windowed: TRUE,
                SwapEffect: DXGI_SWAP_EFFECT_DISCARD,
                ..Default::default()
            };

            // D3D10CreateDeviceAndSwapChain - no FeatureLevel, no DeviceContext
            D3D10CreateDeviceAndSwapChain(
                None,
                D3D10_DRIVER_TYPE_HARDWARE,
                HMODULE::default(),
                0,  // Flags
                D3D10_SDK_VERSION,
                Some(&sc_desc),
                Some(&mut swap_chain),
                Some(&mut device),
            )?;

            let device = device.unwrap();
            let swap_chain = swap_chain.unwrap();

            let back_buffer: ID3D10Resource = swap_chain.GetBuffer(0)?;
            
            let mut render_target_view = None;
            device.CreateRenderTargetView(&back_buffer, None, Some(&mut render_target_view))?;
            let render_target_view = render_target_view.unwrap();

            // Compile vertex shader (use vs_4_0 for D3D10)
            let mut vs_blob = None;
            let mut error_blob = None;
            let compile_flags = D3DCOMPILE_ENABLE_STRICTNESS | D3DCOMPILE_DEBUG;

            let vs_compile_result = D3DCompile(
                SHADER_SOURCE.as_ptr() as _,
                SHADER_SOURCE.len(),
                None,
                None,
                None,
                s!("VSMain"),
                s!("vs_4_0"),  // D3D10 uses Shader Model 4.0
                compile_flags,
                0,
                &mut vs_blob,
                Some(&mut error_blob),
            );

            if let Err(e) = vs_compile_result {
                if let Some(error) = error_blob {
                    let message = std::str::from_utf8(std::slice::from_raw_parts(
                        error.GetBufferPointer() as *const u8,
                        error.GetBufferSize(),
                    )).unwrap_or("Unknown error");
                    println!("VS Compile Error: {}", message);
                }
                return Err(e);
            }
            let vs_blob = vs_blob.unwrap();

            // D3D10 CreateVertexShader - no ClassLinkage parameter
            let mut vertex_shader = None;
            device.CreateVertexShader(
                std::slice::from_raw_parts(vs_blob.GetBufferPointer() as _, vs_blob.GetBufferSize()),
                Some(&mut vertex_shader)
            )?;
            let vertex_shader = vertex_shader.unwrap();

            // Compile pixel shader (use ps_4_0 for D3D10)
            let mut ps_blob = None;
            let ps_compile_result = D3DCompile(
                SHADER_SOURCE.as_ptr() as _,
                SHADER_SOURCE.len(),
                None,
                None,
                None,
                s!("PSMain"),
                s!("ps_4_0"),  // D3D10 uses Shader Model 4.0
                compile_flags,
                0,
                &mut ps_blob,
                None,
            );
            ps_compile_result?;
            let ps_blob = ps_blob.unwrap();

            // D3D10 CreatePixelShader - no ClassLinkage parameter
            let mut pixel_shader = None;
            device.CreatePixelShader(
                std::slice::from_raw_parts(ps_blob.GetBufferPointer() as _, ps_blob.GetBufferSize()),
                Some(&mut pixel_shader)
            )?;
            let pixel_shader = pixel_shader.unwrap();

            // Input layout using D3D10 types
            let input_element_descs = [
                D3D10_INPUT_ELEMENT_DESC {
                    SemanticName: s!("POSITION"),
                    SemanticIndex: 0,
                    Format: DXGI_FORMAT_R32G32B32_FLOAT,
                    InputSlot: 0,
                    AlignedByteOffset: 0,
                    InputSlotClass: D3D10_INPUT_PER_VERTEX_DATA,
                    InstanceDataStepRate: 0,
                },
                D3D10_INPUT_ELEMENT_DESC {
                    SemanticName: s!("COLOR"),
                    SemanticIndex: 0,
                    Format: DXGI_FORMAT_R32G32B32A32_FLOAT,
                    InputSlot: 0,
                    AlignedByteOffset: 12,
                    InputSlotClass: D3D10_INPUT_PER_VERTEX_DATA,
                    InstanceDataStepRate: 0,
                },
            ];

            let mut input_layout = None;
            device.CreateInputLayout(
                &input_element_descs,
                std::slice::from_raw_parts(vs_blob.GetBufferPointer() as _, vs_blob.GetBufferSize()),
                Some(&mut input_layout)
            )?;
            let input_layout = input_layout.unwrap();

            let vertices = [
                Vertex { position: [ 0.0,  0.5, 0.0], color: [1.0, 0.0, 0.0, 1.0] },
                Vertex { position: [ 0.5, -0.5, 0.0], color: [0.0, 1.0, 0.0, 1.0] },
                Vertex { position: [-0.5, -0.5, 0.0], color: [0.0, 0.0, 1.0, 1.0] },
            ];

            // D3D10_BUFFER_DESC - no StructureByteStride
            let buffer_desc = D3D10_BUFFER_DESC {
                ByteWidth: mem::size_of_val(&vertices) as u32,
                Usage: D3D10_USAGE_DEFAULT,
                BindFlags: D3D10_BIND_VERTEX_BUFFER.0 as u32,
                CPUAccessFlags: 0,
                MiscFlags: 0,
            };

            let init_data = D3D10_SUBRESOURCE_DATA {
                pSysMem: vertices.as_ptr() as _,
                SysMemPitch: 0,
                SysMemSlicePitch: 0,
            };

            let mut vertex_buffer = None;
            device.CreateBuffer(&buffer_desc, Some(&init_data), Some(&mut vertex_buffer))?;
            let vertex_buffer = vertex_buffer.unwrap();

            Ok(D3D10App {
                device,
                swap_chain,
                render_target_view,
                vertex_buffer,
                input_layout,
                vertex_shader,
                pixel_shader,
            })
        }
    }

    fn render(&self) {
        unsafe {
            let clear_color = [1.0f32, 1.0, 1.0, 1.0];
            
            // In D3D10, all rendering commands go through the device directly
            self.device.ClearRenderTargetView(&self.render_target_view, &clear_color);

            // D3D10_VIEWPORT uses u32 for Width/Height (different from D3D11 which uses f32)
            let viewport = D3D10_VIEWPORT {
                TopLeftX: 0,
                TopLeftY: 0,
                Width: 640,
                Height: 480,
                MinDepth: 0.0,
                MaxDepth: 1.0,
            };
            self.device.RSSetViewports(Some(&[viewport]));

            self.device.OMSetRenderTargets(Some(&[Some(self.render_target_view.clone())]), None);

            self.device.IASetInputLayout(&self.input_layout);
            self.device.IASetPrimitiveTopology(D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
            
            let stride = mem::size_of::<Vertex>() as u32;
            let offset = 0u32;
            self.device.IASetVertexBuffers(0, 1, Some(&Some(self.vertex_buffer.clone())), Some(&stride), Some(&offset));

            // D3D10 VSSetShader/PSSetShader - no ClassInstances parameter
            self.device.VSSetShader(&self.vertex_shader);
            self.device.PSSetShader(&self.pixel_shader);

            self.device.Draw(3, 0);

            let _ = self.swap_chain.Present(1, DXGI_PRESENT(0));
        }
    }
}

extern "system" fn wndproc(window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    unsafe {
        match message {
            WM_DESTROY => {
                PostQuitMessage(0);
                LRESULT(0)
            }
            _ => DefWindowProcW(window, message, wparam, lparam),
        }
    }
}

fn main() -> Result<()> {
    let instance = unsafe { GetModuleHandleW(None)? };
    let window_class_name = w!("RustD3D10Window");

    let wc = WNDCLASSEXW {
        cbSize: mem::size_of::<WNDCLASSEXW>() as u32,
        style: CS_HREDRAW | CS_VREDRAW,
        lpfnWndProc: Some(wndproc),
        hInstance: instance.into(),
        hCursor: unsafe { LoadCursorW(None, IDC_ARROW)? },
        lpszClassName: window_class_name,
        ..Default::default()
    };

    unsafe { RegisterClassExW(&wc) };

    let hwnd = unsafe {
        CreateWindowExW(
            WINDOW_EX_STYLE::default(),
            window_class_name,
            w!("DirectX 10 Triangle (Rust)"),
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            640,
            480,
            None,
            None,
            Some(instance.into()),
            None,
        )?
    };

    let app = D3D10App::new(hwnd)?;

    let mut message = MSG::default();
    loop {
        unsafe {
            if PeekMessageW(&mut message, None, 0, 0, PM_REMOVE).into() {
                if message.message == WM_QUIT {
                    break;
                }
                let _ = TranslateMessage(&message);
                DispatchMessageW(&message);
            } else {
                app.render();
            }
        }
    }

    Ok(())
}
