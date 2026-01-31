#![windows_subsystem = "windows"]

use windows::{
    core::*, 
    Win32::System::Com::*, 
    Win32::UI::Shell::*,
};

#[allow(non_upper_case_globals)]
const CLSID_Shell: GUID = GUID { data1: 0x13709620, data2: 0xC279, data3: 0x11CE, data4: [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00] };

fn main() -> Result<()> {
    unsafe {
        _ = CoInitializeEx(Some(std::ptr::null_mut()), COINIT_MULTITHREADED);

        let shell: IShellDispatch = CoCreateInstance(&CLSID_Shell, None, CLSCTX_INPROC_SERVER)?;

        let title = BSTR::from("Hello, COM(Rust) World!");
        let root_folder = VARIANT::from(36);
        _ = shell.BrowseForFolder(0, &title, 0, &root_folder);
    }
    Ok(())
}

