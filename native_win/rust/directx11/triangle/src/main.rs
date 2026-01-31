use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Direct3D::Fxc::*,
    Win32::Graphics::Direct3D::*,
    Win32::Graphics::Direct3D11::*,
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

struct D3D11App {
    context: ID3D11DeviceContext,
    swap_chain: IDXGISwapChain,
    render_target_view: ID3D11RenderTargetView,
    vertex_buffer: ID3D11Buffer,
    input_layout: ID3D11InputLayout,
    vertex_shader: ID3D11VertexShader,
    pixel_shader: ID3D11PixelShader,
}

impl D3D11App {
    fn new(hwnd: HWND) -> Result<Self> {
        unsafe {
            let mut device: Option<ID3D11Device> = None;
            let mut context: Option<ID3D11DeviceContext> = None;
            let mut swap_chain: Option<IDXGISwapChain> = None;
            let mut feature_level = D3D_FEATURE_LEVEL_11_0;

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

            D3D11CreateDeviceAndSwapChain(
                None,
                D3D_DRIVER_TYPE_HARDWARE,
                HMODULE::default(), 
                D3D11_CREATE_DEVICE_FLAG(0),
                Some(&[D3D_FEATURE_LEVEL_11_0]),
                D3D11_SDK_VERSION,
                Some(&sc_desc),
                Some(&mut swap_chain),
                Some(&mut device),
                Some(&mut feature_level),
                Some(&mut context),
            )?;

            let device = device.unwrap();
            let context = context.unwrap();
            let swap_chain = swap_chain.unwrap();

            let back_buffer: ID3D11Resource = swap_chain.GetBuffer(0)?;
            
            let mut render_target_view = None;
            device.CreateRenderTargetView(&back_buffer, None, Some(&mut render_target_view))?;
            let render_target_view = render_target_view.unwrap();

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
                s!("vs_5_0"),
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

            let mut vertex_shader = None;
            device.CreateVertexShader(
                std::slice::from_raw_parts(vs_blob.GetBufferPointer() as _, vs_blob.GetBufferSize()),
                None,
                Some(&mut vertex_shader)
            )?;
            let vertex_shader = vertex_shader.unwrap();

            let mut ps_blob = None;
            let ps_compile_result = D3DCompile(
                SHADER_SOURCE.as_ptr() as _,
                SHADER_SOURCE.len(),
                None,
                None,
                None,
                s!("PSMain"),
                s!("ps_5_0"),
                compile_flags,
                0,
                &mut ps_blob,
                None,
            );
            ps_compile_result?;
            let ps_blob = ps_blob.unwrap();

            let mut pixel_shader = None;
            device.CreatePixelShader(
                std::slice::from_raw_parts(ps_blob.GetBufferPointer() as _, ps_blob.GetBufferSize()),
                None,
                Some(&mut pixel_shader)
            )?;
            let pixel_shader = pixel_shader.unwrap();

            let input_element_descs = [
                D3D11_INPUT_ELEMENT_DESC {
                    SemanticName: s!("POSITION"),
                    SemanticIndex: 0,
                    Format: DXGI_FORMAT_R32G32B32_FLOAT,
                    InputSlot: 0,
                    AlignedByteOffset: 0,
                    InputSlotClass: D3D11_INPUT_PER_VERTEX_DATA,
                    InstanceDataStepRate: 0,
                },
                D3D11_INPUT_ELEMENT_DESC {
                    SemanticName: s!("COLOR"),
                    SemanticIndex: 0,
                    Format: DXGI_FORMAT_R32G32B32A32_FLOAT,
                    InputSlot: 0,
                    AlignedByteOffset: 12,
                    InputSlotClass: D3D11_INPUT_PER_VERTEX_DATA,
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

            let buffer_desc = D3D11_BUFFER_DESC {
                ByteWidth: mem::size_of_val(&vertices) as u32,
                Usage: D3D11_USAGE_DEFAULT,
                BindFlags: D3D11_BIND_VERTEX_BUFFER.0 as u32,
                CPUAccessFlags: 0,
                MiscFlags: 0,
                StructureByteStride: 0,
            };

            let init_data = D3D11_SUBRESOURCE_DATA {
                pSysMem: vertices.as_ptr() as _,
                SysMemPitch: 0,
                SysMemSlicePitch: 0,
            };

            let mut vertex_buffer = None;
            device.CreateBuffer(&buffer_desc, Some(&init_data), Some(&mut vertex_buffer))?;
            let vertex_buffer = vertex_buffer.unwrap();

            Ok(D3D11App {
                context,
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
            let clear_color = [0.0, 0.0, 0.0, 1.0];
            self.context.ClearRenderTargetView(&self.render_target_view, &clear_color);

            let viewport = D3D11_VIEWPORT {
                TopLeftX: 0.0,
                TopLeftY: 0.0,
                Width: 640.0,
                Height: 480.0,
                MinDepth: 0.0,
                MaxDepth: 1.0,
            };
            self.context.RSSetViewports(Some(&[viewport]));

            self.context.OMSetRenderTargets(Some(&[Some(self.render_target_view.clone())]), None);

            self.context.IASetInputLayout(&self.input_layout);
            self.context.IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
            let stride = mem::size_of::<Vertex>() as u32;
            let offset = 0;
            self.context.IASetVertexBuffers(0, 1, Some(&Some(self.vertex_buffer.clone())), Some(&stride), Some(&offset));

            self.context.VSSetShader(&self.vertex_shader, None);
            self.context.PSSetShader(&self.pixel_shader, None);

            self.context.Draw(3, 0);

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
    let window_class_name = w!("RustD3D11Window");

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
            w!("DirectX 11 Triangle (Rust)"),
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

    let app = D3D11App::new(hwnd)?;

    let mut message = MSG::default();
    loop {
        unsafe {
            // PeekMessageW (Unicode版)
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
