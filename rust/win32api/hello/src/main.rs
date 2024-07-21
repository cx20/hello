#![windows_subsystem = "windows"]

use windows::{
    core::*,
    Win32::UI::WindowsAndMessaging::*,
};

fn main() {
    unsafe {
        MessageBoxA(None, s!("Hello, Win32 API(Rust) World!"), s!("Hello, World!"), MB_OK);
    }
}
