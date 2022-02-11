use windows::Win32::UI::WindowsAndMessaging::{MessageBoxA, MB_OK};

fn main() {
    unsafe {
        MessageBoxA(None, "Hello, Win32 API(Rust) World!", "Hello, World!", MB_OK);
    }
}
