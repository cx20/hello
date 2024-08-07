#![windows_subsystem = "windows"]

use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Gdi::*,
    Win32::System::LibraryLoader::GetModuleHandleA,
    Win32::UI::WindowsAndMessaging::*
};
use core::ffi::c_void;

fn main() -> Result<()> {
    unsafe {
        let instance = GetModuleHandleA(None)?;
        
        let window_class = s!("window");

        let wc = WNDCLASSA {
            hCursor: LoadCursorW(None, IDC_ARROW)?,
            hInstance: HINSTANCE(instance.0),
            lpszClassName: PCSTR(b"window\0".as_ptr()),

            style: CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc: Some(wndproc),
            ..Default::default()
        };

        let _atom = RegisterClassA(&wc);

        let _hwnd = CreateWindowExA(
            Default::default(),
            window_class,
            s!("Hello, World!"),
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            640,
            480,
            None,
            None,
            instance,
            None
        );

        let mut message = MSG::default();

        while GetMessageA(&mut message, HWND::default(), 0, 0).into() {
            DispatchMessageA(&message);
        }

        Ok(())
    }
}

extern "system" fn wndproc(window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    unsafe {
        match message as u32 {
            WM_PAINT => {
                let mut ps = PAINTSTRUCT::default();
                let hdc = BeginPaint(window, &mut ps);
                draw_triangle(hdc);
                let _ = EndPaint(window, &ps);
                LRESULT(0)
            }
            WM_DESTROY => {
                PostQuitMessage(0);
                LRESULT(0)
            }
            _ => DefWindowProcA(window, message, wparam, lparam),
        }
    }
}

fn draw_triangle(_hdc: HDC) {
    unsafe {
        const WIDTH: i32  = 640;
        const HEIGHT: i32 = 480;
        let _vertex = [
            TRIVERTEX { x: (WIDTH  * 1 / 2), y: (HEIGHT * 1 / 4), Red: 0xffff, Green: 0x0000, Blue: 0x0000, Alpha: 0x0000 },
            TRIVERTEX { x: (WIDTH  * 3 / 4), y: (HEIGHT * 3 / 4), Red: 0x0000, Green: 0xffff, Blue: 0x0000, Alpha: 0x0000 },
            TRIVERTEX { x: (WIDTH  * 1 / 4), y: (HEIGHT * 3 / 4), Red: 0x0000, Green: 0x0000, Blue: 0xffff, Alpha: 0x0000 }
        ];

        let mut _gradient_triangle = GRADIENT_TRIANGLE { Vertex1: 0, Vertex2: 1, Vertex3: 2 };
        let raw_gradient_triangle: *mut GRADIENT_TRIANGLE = &mut _gradient_triangle;
        let _ = GradientFill(_hdc, &_vertex, raw_gradient_triangle as *mut c_void, 1, GRADIENT_FILL_TRIANGLE);
    }
}
