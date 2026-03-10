#![windows_subsystem = "windows"]

use std::ffi::{c_void, CString};
use std::fs;
use std::mem::{size_of, transmute};
use std::path::PathBuf;

use windows::{
    core::{w, Error, HRESULT, HSTRING, IInspectable, IInspectable_Vtbl, IUnknown, Interface, PCSTR, Result},
    Win32::{
        Foundation::{E_FAIL, E_POINTER, FreeLibrary, HINSTANCE, HWND, LPARAM, LRESULT, RPC_E_CHANGED_MODE, WPARAM},
        Graphics::Gdi::UpdateWindow,
        System::{
            Com::{COINIT_APARTMENTTHREADED, CoInitializeEx, CoUninitialize},
            Diagnostics::Debug::OutputDebugStringA,
            LibraryLoader::{GetModuleHandleW, GetProcAddress, LoadLibraryW},
            WinRT::{RO_INIT_SINGLETHREADED, RoActivateInstance, RoGetActivationFactory, RoInitialize, RoUninitialize},
        },
        UI::{
            WindowsAndMessaging::{
                AdjustWindowRect, CreateWindowExW, DefWindowProcW, DispatchMessageW, GetMessageW, IDC_ARROW, LoadCursorW,
                MB_ICONERROR, MB_OK, MSG, MessageBoxW, PostQuitMessage, RegisterClassExW, SW_SHOW, ShowWindow,
                TranslateMessage, WINDOW_EX_STYLE, WNDCLASSEXW, WS_OVERLAPPEDWINDOW, WS_VISIBLE, WM_DESTROY,
            },
        },
    },
};

const WINDOWSAPPSDK_RELEASE_VERSION_TAG_W: PCWSTR = w!("");
const WINDOWSAPPSDK_RELEASE_VERSION_TAG_TEXT: &str = "";

type PCWSTR = windows::core::PCWSTR;

#[repr(C)]
#[derive(Clone, Copy, Default)]
struct PackageVersion {
    version: u64,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
struct DispatcherQueueOptions {
    dw_size: u32,
    thread_type: i32,
    apartment_type: i32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
struct WindowId {
    value: u64,
}

#[derive(Clone, Debug)]
struct BootstrapPackage {
    root: PathBuf,
    package_version_text: String,
    major_minor: u32,
    min_version: u64,
}

type MddBootstrapInitialize2Fn =
    unsafe extern "system" fn(u32, PCWSTR, PackageVersion, u32) -> HRESULT;
type MddBootstrapShutdownFn = unsafe extern "system" fn();
type CreateDispatcherQueueControllerFn =
    unsafe extern "system" fn(DispatcherQueueOptions, *mut *mut c_void) -> HRESULT;
type WindowingGetWindowIdFromWindowFn = unsafe extern "system" fn(HWND, *mut WindowId) -> HRESULT;

const DQTYPE_THREAD_CURRENT: i32 = 2;
const DQTAT_COM_NONE: i32 = 0;

windows::core::imp::define_interface!(
    IWindowsXamlManagerStatics,
    IWindowsXamlManagerStatics_Vtbl,
    0x56cb591d_de97_539f_881d_8ccdc44fa6c4
);
windows::core::imp::interface_hierarchy!(IWindowsXamlManagerStatics, IInspectable, IUnknown);

#[repr(C)]
pub struct IWindowsXamlManagerStatics_Vtbl {
    base__: IInspectable_Vtbl,
    initialize_for_current_thread: unsafe extern "system" fn(*mut c_void, *mut *mut c_void) -> HRESULT,
}

impl IWindowsXamlManagerStatics {
    unsafe fn initialize_for_current_thread(&self) -> Result<IInspectable> {
        let mut value = std::ptr::null_mut();
        (self.vtable().initialize_for_current_thread)(self.as_raw(), &mut value).ok()?;
        if value.is_null() {
            return Err(Error::from(E_POINTER));
        }
        Ok(IInspectable::from_raw(value))
    }
}

windows::core::imp::define_interface!(
    IDesktopWindowXamlSource,
    IDesktopWindowXamlSource_Vtbl,
    0x553af92c_1381_51d6_bee0_f34beb042ea8
);
windows::core::imp::interface_hierarchy!(IDesktopWindowXamlSource, IInspectable, IUnknown);

#[repr(C)]
pub struct IDesktopWindowXamlSource_Vtbl {
    base__: IInspectable_Vtbl,
    get_content: unsafe extern "system" fn(*mut c_void, *mut *mut c_void) -> HRESULT,
    put_content: unsafe extern "system" fn(*mut c_void, *mut c_void) -> HRESULT,
    get_has_focus: unsafe extern "system" fn(*mut c_void, *mut bool) -> HRESULT,
    get_system_backdrop: unsafe extern "system" fn(*mut c_void, *mut *mut c_void) -> HRESULT,
    put_system_backdrop: unsafe extern "system" fn(*mut c_void, *mut c_void) -> HRESULT,
    get_site_bridge: unsafe extern "system" fn(*mut c_void, *mut *mut c_void) -> HRESULT,
    add_take_focus_requested: unsafe extern "system" fn(*mut c_void, *mut c_void, *mut i64) -> HRESULT,
    remove_take_focus_requested: unsafe extern "system" fn(*mut c_void, i64) -> HRESULT,
    add_got_focus: unsafe extern "system" fn(*mut c_void, *mut c_void, *mut i64) -> HRESULT,
    remove_got_focus: unsafe extern "system" fn(*mut c_void, i64) -> HRESULT,
    navigate_focus: unsafe extern "system" fn(*mut c_void, *mut c_void, *mut *mut c_void) -> HRESULT,
    initialize: unsafe extern "system" fn(*mut c_void, WindowId) -> HRESULT,
}

impl IDesktopWindowXamlSource {
    unsafe fn initialize(&self, parent_window_id: WindowId) -> Result<()> {
        (self.vtable().initialize)(self.as_raw(), parent_window_id).ok()
    }

    unsafe fn put_content<T: Interface>(&self, content: &T) -> Result<()> {
        (self.vtable().put_content)(self.as_raw(), content.as_raw()).ok()
    }
}

windows::core::imp::define_interface!(
    IXamlReaderStatics,
    IXamlReaderStatics_Vtbl,
    0x82a4cd9e_435e_5aeb_8c4f_300cece45cae
);
windows::core::imp::interface_hierarchy!(IXamlReaderStatics, IInspectable, IUnknown);

#[repr(C)]
pub struct IXamlReaderStatics_Vtbl {
    base__: IInspectable_Vtbl,
    load: unsafe extern "system" fn(*mut c_void, *mut c_void, *mut *mut c_void) -> HRESULT,
    load_with_initial_template_validation:
        unsafe extern "system" fn(*mut c_void, *mut c_void, *mut *mut c_void) -> HRESULT,
}

impl IXamlReaderStatics {
    unsafe fn load(&self, xaml: &HSTRING) -> Result<IInspectable> {
        let mut value = std::ptr::null_mut();
        (self.vtable().load)(self.as_raw(), transmute_copy_hstring(xaml), &mut value).ok()?;
        if value.is_null() {
            return Err(Error::from(E_POINTER));
        }
        Ok(IInspectable::from_raw(value))
    }
}

windows::core::imp::define_interface!(
    IDispatcherQueueControllerStatics,
    IDispatcherQueueControllerStatics_Vtbl,
    0xf18d6145_722b_593d_bcf2_a61e713f0037
);
windows::core::imp::interface_hierarchy!(IDispatcherQueueControllerStatics, IInspectable, IUnknown);

#[repr(C)]
pub struct IDispatcherQueueControllerStatics_Vtbl {
    base__: IInspectable_Vtbl,
    create_on_dedicated_thread: unsafe extern "system" fn(*mut c_void, *mut *mut c_void) -> HRESULT,
    create_on_current_thread: unsafe extern "system" fn(*mut c_void, *mut *mut c_void) -> HRESULT,
}

impl IDispatcherQueueControllerStatics {
    unsafe fn create_on_current_thread(&self) -> Result<IInspectable> {
        let mut value = std::ptr::null_mut();
        (self.vtable().create_on_current_thread)(self.as_raw(), &mut value).ok()?;
        if value.is_null() {
            return Err(Error::from(E_POINTER));
        }
        Ok(IInspectable::from_raw(value))
    }
}

windows::core::imp::define_interface!(IUIElement, IUIElement_Vtbl, 0xc3c01020_320c_5cf6_9d24_d396bbfa4d8b);
windows::core::imp::interface_hierarchy!(IUIElement, IInspectable, IUnknown);

#[repr(C)]
pub struct IUIElement_Vtbl {
    base__: IInspectable_Vtbl,
}

fn log_state(function_name: &str, message: &str) {
    let line = format!("[{}] {}\n", function_name, message);
    let sanitized = line.replace('\0', " ");
    let c_string = CString::new(sanitized).unwrap_or_else(|_| CString::new("[log_state] invalid string\n").unwrap());
    unsafe {
        OutputDebugStringA(PCSTR(c_string.as_ptr() as *const u8));
    }
}

fn log_hr(function_name: &str, label: &str, hr: HRESULT) {
    log_state(function_name, &format!("{} hr=0x{:08X}", label, hr.0 as u32));
}

fn format_package_version(version: u64) -> String {
    let major = ((version >> 48) & 0xFFFF) as u16;
    let minor = ((version >> 32) & 0xFFFF) as u16;
    let build = ((version >> 16) & 0xFFFF) as u16;
    let revision = (version & 0xFFFF) as u16;
    format!("{}.{}.{}.{}", major, minor, build, revision)
}

fn main() {
    log_state("main", "begin");
    if let Err(error) = run() {
        log_state(
            "main",
            &format!(
                "run failed code=0x{:08X} message={}",
                error.code().0 as u32,
                error.message()
            ),
        );
        let message = HSTRING::from(format!("0x{:08X}: {}", error.code().0 as u32, error.message()));
        unsafe {
            let _ = MessageBoxW(None, &message, w!("Error"), MB_OK | MB_ICONERROR);
        }
    }
    log_state("main", "end");
}

fn run() -> Result<()> {
    unsafe {
        log_state("run", "begin");
        let bootstrap = Bootstrap::initialize()?;
        log_state("run", "bootstrap initialized");

        let co_initialize_hr = CoInitializeEx(None, COINIT_APARTMENTTHREADED);
        log_hr("run", "CoInitializeEx", co_initialize_hr);
        let co_initialized = if co_initialize_hr.is_ok() {
            true
        } else if co_initialize_hr == RPC_E_CHANGED_MODE {
            false
        } else {
            return Err(co_initialize_hr.into());
        };

        let ro_initialized = match RoInitialize(RO_INIT_SINGLETHREADED) {
            Ok(_) => {
                log_state("run", "RoInitialize hr=0x00000000");
                true
            }
            Err(error) if error.code() == RPC_E_CHANGED_MODE => {
                log_hr("run", "RoInitialize", error.code());
                false
            }
            Err(error) => {
                log_hr("run", "RoInitialize", error.code());
                return Err(error);
            }
        };

        let (_dispatcher_queue_controller, _core_dispatcher_queue_controller) = ensure_dispatcher_queue()?;
        log_state("run", "dispatcher queue ready");
        let instance = GetModuleHandleW(None)?;
        log_state("run", &format!("GetModuleHandleW instance=0x{:X}", instance.0 as usize));
        let window = create_main_window(instance.into())?;
        log_state("run", &format!("main window hwnd=0x{:X}", window.0 as usize));
        let _windows_xaml_manager = initialize_windows_xaml_manager()?;
        log_state("run", "WindowsXamlManager initialized");
        let _desktop_window_xaml_source = initialize_xaml_island(window)?;
        log_state("run", "XAML island initialized");

        let mut message = MSG::default();
        log_state("run", "enter message loop");
        while GetMessageW(&mut message, None, 0, 0).into() {
            let _ = TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        log_state("run", "message loop exited");

        if ro_initialized {
            RoUninitialize();
            log_state("run", "RoUninitialize");
        }
        if co_initialized {
            CoUninitialize();
            log_state("run", "CoUninitialize");
        }
        drop(bootstrap);
        log_state("run", "bootstrap shutdown complete");
    }

    log_state("run", "end");
    Ok(())
}

unsafe fn create_main_window(instance: HINSTANCE) -> Result<HWND> {
    log_state("create_main_window", "begin");
    let class_name = w!("HelloWinUI3RustWindow");

    let window_class = WNDCLASSEXW {
        cbSize: size_of::<WNDCLASSEXW>() as u32,
        hInstance: instance,
        lpszClassName: class_name,
        lpfnWndProc: Some(window_proc),
        hCursor: LoadCursorW(None, IDC_ARROW)?,
        ..Default::default()
    };

    let atom = RegisterClassExW(&window_class);
    if atom == 0 {
        log_state("create_main_window", "RegisterClassExW failed");
        return Err(Error::from_win32());
    }
    log_state("create_main_window", &format!("RegisterClassExW atom={}", atom));

    let mut rect = windows::Win32::Foundation::RECT {
        left: 0,
        top: 0,
        right: 960,
        bottom: 540,
    };
    AdjustWindowRect(&mut rect, WS_OVERLAPPEDWINDOW, false)?;
    log_state(
        "create_main_window",
        &format!("adjusted rect={}x{}", rect.right - rect.left, rect.bottom - rect.top),
    );

    let window = CreateWindowExW(
        WINDOW_EX_STYLE::default(),
        class_name,
        w!("Hello, World!"),
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        0x80000000u32 as i32,
        0x80000000u32 as i32,
        rect.right - rect.left,
        rect.bottom - rect.top,
        None,
        None,
        instance,
        None,
    )?;
    log_state("create_main_window", &format!("CreateWindowExW hwnd=0x{:X}", window.0 as usize));

    let _ = ShowWindow(window, SW_SHOW);
    let _ = UpdateWindow(window);
    log_state("create_main_window", "end");
    Ok(window)
}

unsafe fn initialize_windows_xaml_manager() -> Result<IInspectable> {
    log_state("initialize_windows_xaml_manager", "begin");
    let class_name = HSTRING::from("Microsoft.UI.Xaml.Hosting.WindowsXamlManager");
    let factory: IWindowsXamlManagerStatics = RoGetActivationFactory(&class_name)?;
    log_state("initialize_windows_xaml_manager", "RoGetActivationFactory succeeded");
    let manager = factory.initialize_for_current_thread()?;
    log_state("initialize_windows_xaml_manager", "InitializeForCurrentThread succeeded");
    Ok(manager)
}

unsafe fn initialize_xaml_island(parent_window: HWND) -> Result<IDesktopWindowXamlSource> {
    log_state(
        "initialize_xaml_island",
        &format!("begin parent_window=0x{:X}", parent_window.0 as usize),
    );
    let class_name = HSTRING::from("Microsoft.UI.Xaml.Hosting.DesktopWindowXamlSource");
    let source = RoActivateInstance(&class_name)?.cast::<IDesktopWindowXamlSource>()?;
    log_state("initialize_xaml_island", "DesktopWindowXamlSource activated");
    let window_id = get_window_id_for_hwnd(parent_window)?;
    log_state(
        "initialize_xaml_island",
        &format!("window id value={}", window_id.value),
    );
    source.initialize(window_id)?;
    log_state("initialize_xaml_island", "DesktopWindowXamlSource initialized");
    load_triangle_xaml(&source)?;
    log_state("initialize_xaml_island", "triangle xaml loaded");
    Ok(source)
}

unsafe fn load_triangle_xaml(source: &IDesktopWindowXamlSource) -> Result<()> {
    log_state("load_triangle_xaml", "begin");
    let reader_class = HSTRING::from("Microsoft.UI.Xaml.Markup.XamlReader");
    let triangle_xaml = HSTRING::from(
        "<Canvas xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' \
         xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Background='White'>\
         <Path Stroke='Black' StrokeThickness='1'>\
         <Path.Fill>\
         <LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>\
         <GradientStop Color='Red' Offset='0'/>\
         <GradientStop Color='Green' Offset='0.5'/>\
         <GradientStop Color='Blue' Offset='1'/>\
         </LinearGradientBrush>\
         </Path.Fill>\
         <Path.Data>\
         <PathGeometry>\
         <PathFigure StartPoint='300,100' IsClosed='True'>\
         <LineSegment Point='500,400'/>\
         <LineSegment Point='100,400'/>\
         </PathFigure>\
         </PathGeometry>\
         </Path.Data>\
         </Path>\
         </Canvas>",
    );

    let reader: IXamlReaderStatics = RoGetActivationFactory(&reader_class)?;
    log_state("load_triangle_xaml", "XamlReader activation factory acquired");
    let root = reader.load(&triangle_xaml)?;
    log_state("load_triangle_xaml", "XamlReader::Load succeeded");
    let ui_element = root.cast::<IUIElement>()?;
    log_state("load_triangle_xaml", "root cast to IUIElement");
    source.put_content(&ui_element)?;
    log_state("load_triangle_xaml", "put_Content succeeded");
    Ok(())
}

unsafe fn get_window_id_for_hwnd(hwnd: HWND) -> Result<WindowId> {
    log_state("get_window_id_for_hwnd", &format!("begin hwnd=0x{:X}", hwnd.0 as usize));
    let library = load_library_any(&[
        PathBuf::from("Microsoft.Internal.FrameworkUdk.dll"),
        bootstrap_runtime_dll("Microsoft.Internal.FrameworkUdk.dll")?,
    ])?;
    log_state("get_window_id_for_hwnd", &format!("framework udk module=0x{:X}", library.0 as usize));

    let proc = GetProcAddress(library, windows::core::s!("Windowing_GetWindowIdFromWindow"))
        .ok_or_else(Error::from_win32)?;
    let windowing_get_window_id_from_window: WindowingGetWindowIdFromWindowFn = transmute(proc);

    let mut window_id = WindowId::default();
    let result = windowing_get_window_id_from_window(hwnd, &mut window_id);
    log_hr("get_window_id_for_hwnd", "Windowing_GetWindowIdFromWindow", result);
    let _ = FreeLibrary(library);
    result.ok()?;
    log_state("get_window_id_for_hwnd", &format!("end value={}", window_id.value));
    Ok(window_id)
}

unsafe fn ensure_dispatcher_queue() -> Result<(IInspectable, *mut c_void)> {
    log_state("ensure_dispatcher_queue", "begin");
    let dispatcher_queue_class = HSTRING::from("Microsoft.UI.Dispatching.DispatcherQueueController");
    let dispatcher_queue_factory: IDispatcherQueueControllerStatics =
        RoGetActivationFactory(&dispatcher_queue_class)?;
    log_state("ensure_dispatcher_queue", "DispatcherQueueController factory acquired");
    let dispatcher_queue_controller = dispatcher_queue_factory.create_on_current_thread()?;
    log_state("ensure_dispatcher_queue", "CreateOnCurrentThread succeeded");

    let library = GetModuleHandleW(w!("CoreMessaging.dll")).or_else(|_| LoadLibraryW(w!("CoreMessaging.dll")))?;
    log_state("ensure_dispatcher_queue", &format!("CoreMessaging module=0x{:X}", library.0 as usize));
    let proc = GetProcAddress(library, windows::core::s!("CreateDispatcherQueueController"))
        .ok_or_else(Error::from_win32)?;
    let create_dispatcher_queue_controller: CreateDispatcherQueueControllerFn = transmute(proc);

    let options = DispatcherQueueOptions {
        dw_size: size_of::<DispatcherQueueOptions>() as u32,
        thread_type: DQTYPE_THREAD_CURRENT,
        apartment_type: DQTAT_COM_NONE,
    };

    let mut controller = std::ptr::null_mut();
    let hr = create_dispatcher_queue_controller(options, &mut controller);
    log_hr("ensure_dispatcher_queue", "CreateDispatcherQueueController", hr);
    hr.ok()?;
    if controller.is_null() {
        log_state("ensure_dispatcher_queue", "controller was null");
        return Err(Error::from(E_POINTER));
    }
    log_state(
        "ensure_dispatcher_queue",
        &format!("end controller=0x{:X}", controller as usize),
    );
    Ok((dispatcher_queue_controller, controller))
}

unsafe extern "system" fn window_proc(window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    match message {
        WM_DESTROY => {
            log_state("window_proc", "WM_DESTROY");
            PostQuitMessage(0);
            LRESULT(0)
        }
        _ => DefWindowProcW(window, message, wparam, lparam),
    }
}

struct Bootstrap {
    module: windows::Win32::Foundation::HMODULE,
    shutdown: MddBootstrapShutdownFn,
}

impl Bootstrap {
    fn initialize() -> Result<Self> {
        unsafe {
            log_state("Bootstrap::initialize", "begin");
            let package = resolve_bootstrap_package()?;
            log_state(
                "Bootstrap::initialize",
                &format!(
                    "request Major.Minor=0x{:08X} Tag={} MinVersion={}",
                    package.major_minor,
                    WINDOWSAPPSDK_RELEASE_VERSION_TAG_TEXT,
                    format_package_version(package.min_version)
                ),
            );
            let dll_path = bootstrap_runtime_dll("Microsoft.WindowsAppRuntime.Bootstrap.dll")?;
            log_state(
                "Bootstrap::initialize",
                &format!("bootstrap dll path={}", dll_path.display()),
            );
            log_state(
                "Bootstrap::initialize",
                &format!("selected package version={}", package.package_version_text),
            );
            let module = LoadLibraryW(&HSTRING::from(dll_path.as_os_str().to_string_lossy().to_string()))?;
            log_state(
                "Bootstrap::initialize",
                &format!("LoadLibraryW module=0x{:X}", module.0 as usize),
            );
            let init_proc = GetProcAddress(module, windows::core::s!("MddBootstrapInitialize2"))
                .ok_or_else(Error::from_win32)?;
            let shutdown_proc = GetProcAddress(module, windows::core::s!("MddBootstrapShutdown"))
                .ok_or_else(Error::from_win32)?;
            log_state("Bootstrap::initialize", "GetProcAddress succeeded");

            let initialize: MddBootstrapInitialize2Fn = transmute(init_proc);
            let shutdown: MddBootstrapShutdownFn = transmute(shutdown_proc);

            let hr = initialize(
                package.major_minor,
                WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
                PackageVersion {
                    version: package.min_version,
                },
                0,
            );
            log_hr("Bootstrap::initialize", "MddBootstrapInitialize2", hr);
            hr.ok()?;

            log_state("Bootstrap::initialize", "end");
            Ok(Self { module, shutdown })
        }
    }
}

impl Drop for Bootstrap {
    fn drop(&mut self) {
        unsafe {
            log_state("Bootstrap::drop", "begin");
            (self.shutdown)();
            let _ = FreeLibrary(self.module);
            log_state("Bootstrap::drop", "end");
        }
    }
}

fn bootstrap_runtime_dll(file_name: &str) -> Result<PathBuf> {
    log_state("bootstrap_runtime_dll", &format!("begin file_name={}", file_name));
    let package_root = if file_name.eq_ignore_ascii_case("Microsoft.Internal.FrameworkUdk.dll") {
        resolve_package_containing_file(
            "resolve_framework_udk_package",
            &["microsoft.windowsappsdk.interactiveexperiences"],
            file_name,
        )?
    } else {
        resolve_bootstrap_package()?.root
    };
    log_state(
        "bootstrap_runtime_dll",
        &format!("package root={}", package_root.display()),
    );
    let arch = current_arch_folder();
    if arch == "unsupported" {
        return Err(Error::new(E_FAIL, "Unsupported architecture"));
    }

    let direct_path = package_root.join("runtimes").join(arch).join("native").join(file_name);
    if direct_path.exists() {
        log_state(
            "bootstrap_runtime_dll",
            &format!("resolved direct path={}", direct_path.display()),
        );
        return Ok(direct_path);
    }

    let framework_path = package_root
        .join("runtimes-framework")
        .join(arch)
        .join("native")
        .join(file_name);
    if framework_path.exists() {
        log_state(
            "bootstrap_runtime_dll",
            &format!("resolved framework path={}", framework_path.display()),
        );
        return Ok(framework_path);
    }

    let fallback_path = package_root.join("lib").join(arch).join(file_name);
    if fallback_path.exists() {
        log_state(
            "bootstrap_runtime_dll",
            &format!("resolved fallback path={}", fallback_path.display()),
        );
        return Ok(fallback_path);
    }

    log_state("bootstrap_runtime_dll", "failed to resolve path");
    Err(Error::new(
        E_FAIL,
        format!("Could not locate {}", file_name),
    ))
}

fn resolve_package_containing_file(
    log_name: &str,
    package_names: &[&str],
    file_name: &str,
) -> Result<PathBuf> {
    log_state(log_name, &format!("begin file_name={}", file_name));
    let base = std::env::var_os("NUGET_PACKAGES")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("USERPROFILE").map(|home| PathBuf::from(home).join(".nuget").join("packages")))
        .ok_or_else(|| Error::new(E_FAIL, "NuGet package cache was not found"))?;
    log_state(log_name, &format!("base={}", base.display()));

    let mut candidates = Vec::new();
    for package_name in package_names {
        let package_dir = base.join(package_name);
        log_state(log_name, &format!("scan package dir={}", package_dir.display()));
        if let Ok(entries) = fs::read_dir(&package_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    candidates.push(path);
                }
            }
        }
    }

    candidates.sort();
    for candidate in candidates.into_iter().rev() {
        let direct = candidate
            .join("runtimes")
            .join(current_arch_folder())
            .join("native")
            .join(file_name);
        if direct.exists() {
            log_state(log_name, &format!("selected direct={}", direct.display()));
            return Ok(candidate);
        }

        let framework = candidate
            .join("runtimes-framework")
            .join(current_arch_folder())
            .join("native")
            .join(file_name);
        if framework.exists() {
            log_state(log_name, &format!("selected framework={}", framework.display()));
            return Ok(candidate);
        }
    }

    Err(Error::new(
        E_FAIL,
        format!("No package contained {}", file_name),
    ))
}

fn current_arch_folder() -> &'static str {
    if cfg!(target_arch = "x86_64") {
        "win-x64"
    } else if cfg!(target_arch = "x86") {
        "win-x86"
    } else if cfg!(target_arch = "aarch64") {
        "win-arm64"
    } else {
        "unsupported"
    }
}

fn parse_major_minor_from_version(version: &str) -> Result<u32> {
    let mut parts = version.split('.');
    let major = parts
        .next()
        .ok_or_else(|| Error::new(E_FAIL, "Missing major version"))?
        .parse::<u32>()
        .map_err(|_| Error::new(E_FAIL, "Invalid major version"))?;
    let minor = parts
        .next()
        .ok_or_else(|| Error::new(E_FAIL, "Missing minor version"))?
        .parse::<u32>()
        .map_err(|_| Error::new(E_FAIL, "Invalid minor version"))?;
    Ok((major << 16) | minor)
}

fn resolve_bootstrap_package() -> Result<BootstrapPackage> {
    log_state("resolve_bootstrap_package", "begin");
    let base = std::env::var_os("NUGET_PACKAGES")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("USERPROFILE").map(|home| PathBuf::from(home).join(".nuget").join("packages")))
        .ok_or_else(|| Error::new(E_FAIL, "NuGet package cache was not found"))?;
    log_state("resolve_bootstrap_package", &format!("base={}", base.display()));

    let mut candidates = Vec::new();
    for package_name in ["microsoft.windowsappsdk", "microsoft.windowsappsdk.foundation"] {
        let package_dir = base.join(package_name);
        log_state(
            "resolve_bootstrap_package",
            &format!("scan package dir={}", package_dir.display()),
        );
        if let Ok(entries) = fs::read_dir(&package_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    candidates.push(path);
                }
            }
        }
    }

    candidates.sort();
    let path = candidates
        .into_iter()
        .rev()
        .find(|path| path.join("include").join("MddBootstrap.h").exists())
        .ok_or_else(|| Error::new(E_FAIL, "Windows App SDK NuGet package was not found"))?;

    let package_version_text = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| Error::new(E_FAIL, "Windows App SDK package version could not be determined"))?
        .to_string();
    let major_minor = parse_major_minor_from_version(&package_version_text)?;

    log_state(
        "resolve_bootstrap_package",
        &format!(
            "selected={} package_version={} major_minor=0x{:08X}",
            path.display(),
            package_version_text,
            major_minor
        ),
    );

    Ok(BootstrapPackage {
        root: path,
        package_version_text,
        major_minor,
        min_version: 0,
    })
}

unsafe fn load_library_any(candidates: &[PathBuf]) -> Result<windows::Win32::Foundation::HMODULE> {
    log_state("load_library_any", "begin");
    for candidate in candidates {
        if candidate.as_os_str().is_empty() {
            continue;
        }
        log_state("load_library_any", &format!("try={}", candidate.display()));

        let module = LoadLibraryW(&HSTRING::from(candidate.as_os_str().to_string_lossy().to_string()));

        if let Ok(module) = module {
            log_state(
                "load_library_any",
                &format!("loaded {} module=0x{:X}", candidate.display(), module.0 as usize),
            );
            return Ok(module);
        }
    }

    log_state("load_library_any", "failed");
    Err(Error::from_win32())
}

unsafe fn transmute_copy_hstring(value: &HSTRING) -> *mut c_void {
    transmute(value.clone())
}
