#![windows_subsystem = "windows"]

use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Gdi::*,
    Win32::Graphics::OpenGL::*,
    Win32::System::LibraryLoader::GetModuleHandleA,
    Win32::UI::WindowsAndMessaging::*
};

fn main() -> Result<()> {
    unsafe {
        let instance = GetModuleHandleA(None)?;

        let window_class = s!("window");

        let wc = WNDCLASSA {
            hCursor: LoadCursorW(None, IDC_ARROW).unwrap(),
            hInstance: HINSTANCE(instance.0),
            lpszClassName: PCSTR(b"window\0".as_ptr()),

            style: CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc: Some(wndproc),
            ..Default::default()
        };

        let _atom = RegisterClassA(&wc);

        let hwnd = CreateWindowExA(
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
            None,
        )?;

        let hdc = GetDC(hwnd);
        let hrc = enable_open_gl(hdc);

        loop {
            let mut message = MSG::default();

            if PeekMessageA(&mut message, None, 0, 0, PM_REMOVE).into() {
                _ = TranslateMessage(&message);
                DispatchMessageA(&message);

                if message.message == WM_QUIT {
                    break;
                }
            } else {
                glClearColor(0.0, 0.0, 0.0, 0.0);
                glClear(GL_COLOR_BUFFER_BIT);

                draw_triangle();

                _ = SwapBuffers(hdc);

            }
        }

    disable_open_gl(hwnd, hdc, hrc);
    _ = DestroyWindow(hwnd);

        Ok(())
    }
}

fn enable_open_gl(hdc: HDC) -> HGLRC {
    unsafe {
        let pfd = PIXELFORMATDESCRIPTOR {
            dwFlags: PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
            iPixelType: PFD_TYPE_RGBA,
            cColorBits: 32,
            cDepthBits: 24,
            cStencilBits: 8,
            iLayerType: PFD_MAIN_PLANE.0 as u8,
            ..Default::default()
        };

        let i_format = ChoosePixelFormat(hdc, &pfd);

        _ = SetPixelFormat(hdc, i_format, &pfd);

        let hrc = wglCreateContext(hdc).unwrap();
        _ = wglMakeCurrent(hdc, hrc);
        
        hrc
    }
}

fn disable_open_gl(hwnd: HWND, hdc: HDC, hrc: HGLRC) {
    unsafe {
        _ = wglMakeCurrent(None, None);
        _ = wglDeleteContext(hrc);
        ReleaseDC(hwnd, hdc);
    }
}

fn draw_triangle() {
    unsafe {
        glBegin(GL_TRIANGLES);

            glColor3f(1.0, 0.0, 0.0);   glVertex2f( 0.0,  0.50);
            glColor3f(0.0, 1.0, 0.0);   glVertex2f( 0.5, -0.50);
            glColor3f(0.0, 0.0, 1.0);   glVertex2f(-0.5, -0.50);

        glEnd();
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
