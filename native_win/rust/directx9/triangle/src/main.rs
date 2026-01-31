// src/main.rs
use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Direct3D9::*,
    Win32::Graphics::Gdi::*,
    Win32::System::LibraryLoader::*,
    Win32::UI::WindowsAndMessaging::*,
};

use std::mem;
use std::ptr;

// FVF flags
const D3DFVF_XYZRHW: u32 = 0x004;
const D3DFVF_DIFFUSE: u32 = 0x040;
const D3DFVF_VERTEX: u32 = D3DFVF_XYZRHW | D3DFVF_DIFFUSE;

// Vertex structure (transformed with diffuse color)
#[repr(C)]
struct Vertex {
    x: f32,
    y: f32,
    z: f32,
    rhw: f32,
    color: u32,
}

// D3DCOLOR_XRGB macro replacement
fn d3dcolor_xrgb(r: u8, g: u8, b: u8) -> u32 {
    0xFF000000 | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)
}

struct D3D9App {
    device: IDirect3DDevice9,
    vertex_buffer: IDirect3DVertexBuffer9,
}

impl D3D9App {
    fn new(hwnd: HWND) -> Result<Self> {
        unsafe {
            // Create Direct3D9 object
            let d3d: IDirect3D9 = Direct3DCreate9(D3D_SDK_VERSION)
                .ok_or_else(|| Error::from_hresult(HRESULT(-1)))?;

            // Set up present parameters
            let mut d3dpp = D3DPRESENT_PARAMETERS {
                Windowed: TRUE,
                SwapEffect: D3DSWAPEFFECT_DISCARD,
                BackBufferFormat: D3DFMT_UNKNOWN,
                hDeviceWindow: hwnd,
                ..mem::zeroed()
            };

            // Create device
            let mut device: Option<IDirect3DDevice9> = None;
            d3d.CreateDevice(
                D3DADAPTER_DEFAULT,
                D3DDEVTYPE_HAL,
                hwnd,
                D3DCREATE_SOFTWARE_VERTEXPROCESSING as u32,
                &mut d3dpp,
                &mut device,
            )?;
            let device = device.unwrap();

            // Create vertex buffer
            let vertices = [
                Vertex { x: 320.0, y: 100.0, z: 0.0, rhw: 1.0, color: d3dcolor_xrgb(255, 0, 0) }, // Red
                Vertex { x: 520.0, y: 380.0, z: 0.0, rhw: 1.0, color: d3dcolor_xrgb(0, 255, 0) }, // Green
                Vertex { x: 120.0, y: 380.0, z: 0.0, rhw: 1.0, color: d3dcolor_xrgb(0, 0, 255) }, // Blue
            ];

            let mut vertex_buffer: Option<IDirect3DVertexBuffer9> = None;
            device.CreateVertexBuffer(
                (3 * mem::size_of::<Vertex>()) as u32,
                0,
                D3DFVF_VERTEX,
                D3DPOOL_DEFAULT,
                &mut vertex_buffer,
                ptr::null_mut(),
            )?;
            let vertex_buffer = vertex_buffer.unwrap();

            // Lock and fill vertex buffer
            let mut p_vertices: *mut std::ffi::c_void = ptr::null_mut();
            vertex_buffer.Lock(0, 0, &mut p_vertices, 0)?;
            ptr::copy_nonoverlapping(
                vertices.as_ptr(),
                p_vertices as *mut Vertex,
                vertices.len(),
            );
            vertex_buffer.Unlock()?;

            Ok(D3D9App {
                device,
                vertex_buffer,
            })
        }
    }

    fn render(&self) {
        unsafe {
            // Clear the backbuffer to white
            let _ = self.device.Clear(
                0,
                ptr::null(),
                D3DCLEAR_TARGET as u32,
                d3dcolor_xrgb(255, 255, 255),
                1.0,
                0,
            );

            // Begin scene
            if self.device.BeginScene().is_ok() {
                // Set stream source
                let _ = self.device.SetStreamSource(
                    0,
                    &self.vertex_buffer,
                    0,
                    mem::size_of::<Vertex>() as u32,
                );

                // Set FVF
                let _ = self.device.SetFVF(D3DFVF_VERTEX);

                // Draw triangle
                let _ = self.device.DrawPrimitive(D3DPT_TRIANGLELIST, 0, 1);

                // End scene
                let _ = self.device.EndScene();
            }

            // Present
            let _ = self.device.Present(
                ptr::null(),
                ptr::null(),
                HWND::default(),
                ptr::null(),
            );
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
    let window_class_name = w!("RustD3D9Window");

    let wc = WNDCLASSEXW {
        cbSize: mem::size_of::<WNDCLASSEXW>() as u32,
        style: CS_HREDRAW | CS_VREDRAW,
        lpfnWndProc: Some(wndproc),
        hInstance: instance.into(),
        hCursor: unsafe { LoadCursorW(None, IDC_ARROW)? },
        hbrBackground: HBRUSH((COLOR_WINDOW.0 + 1) as *mut std::ffi::c_void),
        lpszClassName: window_class_name,
        ..Default::default()
    };

    unsafe { RegisterClassExW(&wc) };

    let hwnd = unsafe {
        CreateWindowExW(
            WINDOW_EX_STYLE::default(),
            window_class_name,
            w!("Hello, World!"),
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

    let app = D3D9App::new(hwnd)?;

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