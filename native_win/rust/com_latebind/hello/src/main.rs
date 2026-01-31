#![windows_subsystem = "windows"]

use windows::{
    core::*,
    Win32::System::Com::*,
};

// LOCALE_USER_DEFAULT is not exported, define manually
const LOCALE_USER_DEFAULT: u32 = 0x0400;

fn main() -> Result<()> {
    unsafe {
        _ = CoInitializeEx(Some(std::ptr::null_mut()), COINIT_MULTITHREADED);

        // Get CLSID from ProgID (late binding approach)
        let prog_id: PCWSTR = w!("Shell.Application");
        let clsid = CLSIDFromProgID(prog_id)?;

        // Get IDispatch interface
        let shell: IDispatch = CoCreateInstance(&clsid, None, CLSCTX_INPROC_SERVER)?;

        // Get DISPID from method name
        let method_name = HSTRING::from("BrowseForFolder");
        let mut names = [PCWSTR(method_name.as_ptr())];
        let mut dispid: i32 = 0;
        shell.GetIDsOfNames(
            &GUID::zeroed(),
            names.as_mut_ptr(),
            1,
            LOCALE_USER_DEFAULT,
            &mut dispid,
        )?;

        // Prepare arguments (in reverse order)
        let mut args: [VARIANT; 4] = [
            VARIANT::from(36i32),                                  // RootFolder (ssfWINDOWS = 36)
            VARIANT::from(0i32),                                   // Options
            VARIANT::from(BSTR::from("Hello, COM(Rust) World!")),  // Title
            VARIANT::from(0i32),                                   // Hwnd
        ];

        // Set DISPPARAMS
        let mut params = DISPPARAMS {
            rgvarg: args.as_mut_ptr(),
            rgdispidNamedArgs: std::ptr::null_mut(),
            cArgs: 4,
            cNamedArgs: 0,
        };

        // Invoke method
        let mut result = VARIANT::default();
        shell.Invoke(
            dispid,
            &GUID::zeroed(),
            LOCALE_USER_DEFAULT,
            DISPATCH_METHOD,
            &mut params,
            Some(&mut result),
            None,
            None,
        )?;
    }
    Ok(())
}