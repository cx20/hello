#![windows_subsystem = "windows"]

use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Gdi::*,
    Win32::System::LibraryLoader::GetModuleHandleA,
    Win32::UI::WindowsAndMessaging::*,
};

fn main() -> Result<()> {
    unsafe {
        let instance = GetModuleHandleA(None)?;

        let window_class = s!("window");

        let wc = WNDCLASSA {
            hCursor: LoadCursorA(None, PCSTR(IDC_ARROW.0 as *const u8))?,
            hInstance: HINSTANCE(instance.0),
            lpszClassName: PCSTR(window_class.as_ptr() as *const u8),
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
            None,
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
        match message {
            WM_PAINT => {
                let mut ps = PAINTSTRUCT::default();
                let hdc = BeginPaint(window, &mut ps);
                let text = "Hello, Win32 GUI(Rust) World!";
                let _ = TextOutA(hdc, 0, 0, text.as_bytes());
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
