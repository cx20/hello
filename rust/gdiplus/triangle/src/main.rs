#![windows_subsystem = "windows"]

use std::ffi::c_void;
use std::mem::zeroed;
use std::ptr::null_mut;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::OnceLock;
use windows::{
    core::*,
    Win32::Foundation::*,
    Win32::Graphics::Gdi::*,
    Win32::System::LibraryLoader::{GetModuleHandleA, GetProcAddress, LoadLibraryA},
    Win32::UI::WindowsAndMessaging::*,
};

// GDI+ types
type GpStatus = i32;
type GpGraphics = *mut c_void;
type GpPath = *mut c_void;
type GpBrush = *mut c_void;
type ARGB = u32;

#[repr(C)]
struct GdiplusStartupInput {
    gdiplus_version: u32,
    debug_event_callback: *mut c_void,
    suppress_background_thread: i32,
    suppress_external_codecs: i32,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct GpPoint {
    x: i32,
    y: i32,
}

const FILL_MODE_ALTERNATE: i32 = 0;

// GDI+ function pointer types
type FnGdiplusStartup = unsafe extern "system" fn(*mut usize, *const GdiplusStartupInput, *mut c_void) -> GpStatus;
type FnGdiplusShutdown = unsafe extern "system" fn(usize);
type FnGdipCreateFromHDC = unsafe extern "system" fn(HDC, *mut GpGraphics) -> GpStatus;
type FnGdipDeleteGraphics = unsafe extern "system" fn(GpGraphics) -> GpStatus;
type FnGdipCreatePath = unsafe extern "system" fn(i32, *mut GpPath) -> GpStatus;
type FnGdipDeletePath = unsafe extern "system" fn(GpPath) -> GpStatus;
type FnGdipAddPathLine2I = unsafe extern "system" fn(GpPath, *const GpPoint, i32) -> GpStatus;
type FnGdipClosePathFigure = unsafe extern "system" fn(GpPath) -> GpStatus;
type FnGdipCreatePathGradientFromPath = unsafe extern "system" fn(GpPath, *mut GpBrush) -> GpStatus;
type FnGdipDeleteBrush = unsafe extern "system" fn(GpBrush) -> GpStatus;
type FnGdipSetPathGradientCenterColor = unsafe extern "system" fn(GpBrush, ARGB) -> GpStatus;
type FnGdipSetPathGradientSurroundColorsWithCount = unsafe extern "system" fn(GpBrush, *const ARGB, *mut i32) -> GpStatus;
type FnGdipFillPath = unsafe extern "system" fn(GpGraphics, GpBrush, GpPath) -> GpStatus;

// GDI+ function pointers container
struct GdiplusFunctions {
    startup: FnGdiplusStartup,
    shutdown: FnGdiplusShutdown,
    create_from_hdc: FnGdipCreateFromHDC,
    delete_graphics: FnGdipDeleteGraphics,
    create_path: FnGdipCreatePath,
    delete_path: FnGdipDeletePath,
    add_path_line2i: FnGdipAddPathLine2I,
    close_path_figure: FnGdipClosePathFigure,
    create_path_gradient_from_path: FnGdipCreatePathGradientFromPath,
    delete_brush: FnGdipDeleteBrush,
    set_path_gradient_center_color: FnGdipSetPathGradientCenterColor,
    set_path_gradient_surround_colors_with_count: FnGdipSetPathGradientSurroundColorsWithCount,
    fill_path: FnGdipFillPath,
}

// Safe global state
static GDIPLUS_TOKEN: AtomicUsize = AtomicUsize::new(0);
static GDIPLUS_FUNCS: OnceLock<GdiplusFunctions> = OnceLock::new();

fn make_argb(a: u8, r: u8, g: u8, b: u8) -> ARGB {
    ((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)
}

unsafe fn load_gdiplus() -> bool {
    let lib = match LoadLibraryA(s!("gdiplus.dll")) {
        Ok(h) => h,
        Err(_) => return false,
    };

    macro_rules! load_proc {
        ($proc_name:expr) => {{
            let proc = GetProcAddress(lib, PCSTR($proc_name.as_ptr()));
            if proc.is_none() {
                return false;
            }
            std::mem::transmute(proc.unwrap())
        }};
    }

    let funcs = GdiplusFunctions {
        startup: load_proc!(b"GdiplusStartup\0"),
        shutdown: load_proc!(b"GdiplusShutdown\0"),
        create_from_hdc: load_proc!(b"GdipCreateFromHDC\0"),
        delete_graphics: load_proc!(b"GdipDeleteGraphics\0"),
        create_path: load_proc!(b"GdipCreatePath\0"),
        delete_path: load_proc!(b"GdipDeletePath\0"),
        add_path_line2i: load_proc!(b"GdipAddPathLine2I\0"),
        close_path_figure: load_proc!(b"GdipClosePathFigure\0"),
        create_path_gradient_from_path: load_proc!(b"GdipCreatePathGradientFromPath\0"),
        delete_brush: load_proc!(b"GdipDeleteBrush\0"),
        set_path_gradient_center_color: load_proc!(b"GdipSetPathGradientCenterColor\0"),
        set_path_gradient_surround_colors_with_count: load_proc!(b"GdipSetPathGradientSurroundColorsWithCount\0"),
        fill_path: load_proc!(b"GdipFillPath\0"),
    };

    GDIPLUS_FUNCS.set(funcs).is_ok()
}

unsafe fn init_gdiplus() -> bool {
    let funcs = match GDIPLUS_FUNCS.get() {
        Some(f) => f,
        None => return false,
    };

    let input = GdiplusStartupInput {
        gdiplus_version: 1,
        debug_event_callback: null_mut(),
        suppress_background_thread: 0,
        suppress_external_codecs: 0,
    };

    let mut token: usize = 0;
    if (funcs.startup)(&mut token, &input, null_mut()) == 0 {
        GDIPLUS_TOKEN.store(token, Ordering::SeqCst);
        true
    } else {
        false
    }
}

unsafe fn shutdown_gdiplus() {
    if let Some(funcs) = GDIPLUS_FUNCS.get() {
        let token = GDIPLUS_TOKEN.load(Ordering::SeqCst);
        (funcs.shutdown)(token);
    }
}

fn draw_triangle(hdc: HDC) {
    let funcs = match GDIPLUS_FUNCS.get() {
        Some(f) => f,
        None => return,
    };

    unsafe {
        const WIDTH: i32 = 640;
        const HEIGHT: i32 = 480;

        let mut graphics: GpGraphics = null_mut();
        let mut path: GpPath = null_mut();
        let mut brush: GpBrush = null_mut();

        // Create Graphics object
        if (funcs.create_from_hdc)(hdc, &mut graphics) != 0 || graphics.is_null() {
            return;
        }

        // Define triangle vertices
        let points = [
            GpPoint { x: WIDTH / 2, y: HEIGHT / 4 },
            GpPoint { x: WIDTH * 3 / 4, y: HEIGHT * 3 / 4 },
            GpPoint { x: WIDTH / 4, y: HEIGHT * 3 / 4 },
        ];

        // Create GraphicsPath
        if (funcs.create_path)(FILL_MODE_ALTERNATE, &mut path) != 0 || path.is_null() {
            (funcs.delete_graphics)(graphics);
            return;
        }

        // Add lines to path
        if (funcs.add_path_line2i)(path, points.as_ptr(), 3) != 0 {
            (funcs.delete_path)(path);
            (funcs.delete_graphics)(graphics);
            return;
        }

        // Close path figure
        (funcs.close_path_figure)(path);

        // Create PathGradientBrush
        if (funcs.create_path_gradient_from_path)(path, &mut brush) != 0 || brush.is_null() {
            (funcs.delete_path)(path);
            (funcs.delete_graphics)(graphics);
            return;
        }

        // Set center color (RGB 85 = 255/3)
        (funcs.set_path_gradient_center_color)(brush, make_argb(255, 85, 85, 85));

        // Set surround colors (red, green, blue)
        let colors: [ARGB; 3] = [
            make_argb(255, 255, 0, 0), // Red
            make_argb(255, 0, 255, 0), // Green
            make_argb(255, 0, 0, 255), // Blue
        ];
        let mut count: i32 = 3;
        (funcs.set_path_gradient_surround_colors_with_count)(brush, colors.as_ptr(), &mut count);

        // Fill path
        (funcs.fill_path)(graphics, brush, path);

        // Release resources
        (funcs.delete_brush)(brush);
        (funcs.delete_path)(path);
        (funcs.delete_graphics)(graphics);
    }
}

extern "system" fn wndproc(window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    unsafe {
        match message {
            WM_PAINT => {
                let mut ps: PAINTSTRUCT = zeroed();
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

fn main() -> Result<()> {
    unsafe {
        // Load and initialize GDI+
        if !load_gdiplus() {
            return Err(Error::from_win32());
        }
        if !init_gdiplus() {
            return Err(Error::from_win32());
        }

        let instance = GetModuleHandleA(None)?;
        let window_class = s!("window");

        let wc = WNDCLASSA {
            hCursor: LoadCursorW(None, IDC_ARROW)?,
            hInstance: HINSTANCE(instance.0),
            lpszClassName: PCSTR(b"window\0".as_ptr()),
            style: CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc: Some(wndproc),
            hbrBackground: HBRUSH((COLOR_WINDOW.0 + 1) as *mut c_void),
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
        )?;

        let mut message = MSG::default();

        while GetMessageA(&mut message, HWND::default(), 0, 0).into() {
            DispatchMessageA(&message);
        }

        // Shutdown GDI+
        shutdown_gdiplus();

        Ok(())
    }
}
