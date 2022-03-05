#![windows_subsystem = "windows"]

use windows::{
    core::*, 
    Win32::Foundation::*,
    Win32::System::Com::*, 
    Win32::System::Ole::*, 
    Win32::UI::Shell::*,
};

#[allow(non_upper_case_globals)]
const CLSID_Shell: GUID = GUID { data1: 0x13709620, data2: 0xC279, data3: 0x11CE, data4: [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00] };

fn main() -> Result<()> {
    unsafe {
        CoInitializeEx(std::ptr::null_mut(), COINIT_MULTITHREADED)?;

        let mut root_folder = VARIANT::default();
        (*root_folder.Anonymous.Anonymous).vt = VT_I4.0 as u16;
        (*root_folder.Anonymous.Anonymous).Anonymous.lVal = 36 as i32;

        let shell: IShellDispatch = CoCreateInstance(&CLSID_Shell, None, CLSCTX_INPROC_SERVER)?;
        _ = shell.BrowseForFolder(0, to_bstr("Hello, COM(Rust) World!"), 0, root_folder);
    }
    Ok(())
}

fn to_bstr(string: &str) -> BSTR {
    let wide: Vec<u16> = string.encode_utf16().collect();
    BSTR::from_wide(&wide)
}
