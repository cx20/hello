#![windows_subsystem = "windows"]

use windows::{
    core::*, Win32::Foundation::*,
    Win32::Graphics::Gdi::*,
    Win32::Graphics::OpenGL::*,
    Win32::System::LibraryLoader::GetModuleHandleA,
    Win32::UI::WindowsAndMessaging::*
};
use core::ffi::c_void;

fn main() -> Result<()> {
    unsafe {
        let instance = GetModuleHandleA(None);
        debug_assert!(instance.0 != 0);

        let window_class = "window";

        let wc = WNDCLASSA {
            hCursor: LoadCursorW(None, IDC_ARROW),
            hInstance: instance,
            lpszClassName: PSTR(b"window\0".as_ptr()),

            style: CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc: Some(wndproc),
            ..Default::default()
        };

        let atom = RegisterClassA(&wc);
        debug_assert!(atom != 0);

        let hwnd = CreateWindowExA(
            Default::default(),
            window_class,
            "Hello, World!",
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            640,
            480,
            None,
            None,
            instance,
            std::ptr::null_mut()
        );

        let hdc = GetDC(hwnd);
        let hrc = enable_open_gl(hdc);

        loop {
            let mut message = MSG::default();

            if PeekMessageA(&mut message, None, 0, 0, PM_REMOVE).into() {
                TranslateMessage(&message);
                DispatchMessageA(&message);

                if message.message == WM_QUIT {
                    break;
                }
            } else {
                glClearColor(0.0, 0.0, 0.0, 0.0);
                glClear(GL_COLOR_BUFFER_BIT);

                draw_triangle();

                SwapBuffers(hdc);

            }
        }

    disable_open_gl(hwnd, hdc, hrc);
    DestroyWindow(hwnd);

        Ok(())
    }
}

fn enable_open_gl(hdc: HDC) -> HGLRC {
    unsafe {
        let pfd = PIXELFORMATDESCRIPTOR {
            dwFlags: PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
            iPixelType: PFD_TYPE_RGBA as u8,
            cColorBits: 32,
            cDepthBits: 24,
            cStencilBits: 8,
            iLayerType: PFD_MAIN_PLANE as u8,
            ..Default::default()
        };

        let i_format = ChoosePixelFormat(hdc, &pfd);

        SetPixelFormat(hdc, i_format, &pfd);

        let hrc = wglCreateContext(hdc);
        wglMakeCurrent(hdc, hrc);
        
        hrc
    }
}

fn disable_open_gl(hwnd: HWND, hdc: HDC, hrc: HGLRC) {
    unsafe {
        wglMakeCurrent(None, None);
        wglDeleteContext(hrc);
        ReleaseDC(hwnd, hdc);
    }
}

fn draw_triangle() {
    unsafe {
        glEnableClientState(GL_COLOR_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);

        let colors: [f32; 9] = [
             1.0,  0.0,  0.0,
             0.0,  1.0,  0.0,
             0.0,  0.0,  1.0
        ];
        let vertices: [f32; 6] = [
             0.0,  0.5,
             0.5, -0.5,
            -0.5, -0.5,
        ];

        glColorPointer(3, GL_FLOAT, 0, colors.as_ptr() as *mut c_void);
        glVertexPointer(2, GL_FLOAT, 0, vertices.as_ptr() as *mut c_void);

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
    }
}

extern "system" fn wndproc(window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    unsafe {
        match message as u32 {
            WM_DESTROY => {
                PostQuitMessage(0);
                LRESULT(0)
            }
            _ => DefWindowProcA(window, message, wparam, lparam),
        }
    }
}
