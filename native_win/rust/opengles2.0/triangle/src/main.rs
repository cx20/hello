#![windows_subsystem = "windows"]

use gl::types::*;
use std::ffi::{CStr, CString};
use std::ffi::c_void;
use std::mem;
use std::ptr;
use winapi::shared::minwindef::{HMODULE, LPARAM, WPARAM};
use winapi::shared::windef::{HDC, HGLRC, HWND};
use winapi::um::debugapi::OutputDebugStringA;
use winapi::um::errhandlingapi::GetLastError;
use winapi::um::libloaderapi::{GetModuleHandleA, GetProcAddress, LoadLibraryA};
use winapi::um::wingdi::*;
use winapi::um::winuser::*;

const WGL_CONTEXT_MAJOR_VERSION_ARB: i32 = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB: i32 = 0x2092;
const WGL_CONTEXT_FLAGS_ARB: i32 = 0x2094;
const WGL_CONTEXT_PROFILE_MASK_ARB: i32 = 0x9126;
const WGL_CONTEXT_ES2_PROFILE_BIT_EXT: i32 = 0x0000_0004;

static VERTEX_DATA: [GLfloat; 9] = [
    0.0, 0.5, 0.0, //
    0.5, -0.5, 0.0, //
    -0.5, -0.5, 0.0,
];

static COLOR_DATA: [GLfloat; 9] = [
    1.0, 0.0, 0.0, //
    0.0, 1.0, 0.0, //
    0.0, 0.0, 1.0,
];

// OpenGL ES 2.0 shaders (same style as the C sample).
static VS_SRC: &str = "attribute vec3 position;                     \n\
attribute vec3 color;                        \n\
varying   vec4 vColor;                       \n\
void main()                                  \n\
{                                            \n\
  vColor = vec4(color, 1.0);                 \n\
  gl_Position = vec4(position, 1.0);         \n\
}                                            \n";

static FS_SRC: &str = "precision mediump float;                     \n\
varying   vec4 vColor;                       \n\
void main()                                  \n\
{                                            \n\
  gl_FragColor = vColor;                     \n\
}                                            \n";

static mut SHOULD_CLOSE: bool = false;
static mut VBO: [GLuint; 2] = [0, 0];
static mut POS_ATTR: GLint = -1;
static mut COL_ATTR: GLint = -1;
static mut FRAME_COUNT: u32 = 0;
static mut GL_READY: bool = false;

fn log_debug(function: &str, state: &str) {
    let text = format!("[{}] {}\n", function, state).replace('\0', " ");
    if let Ok(c_text) = CString::new(text) {
        unsafe {
            OutputDebugStringA(c_text.as_ptr());
        }
    }
}

fn gl_string(name: GLenum) -> String {
    unsafe {
        let p = gl::GetString(name);
        if p.is_null() {
            "null".to_string()
        } else {
            CStr::from_ptr(p as *const i8).to_string_lossy().into_owned()
        }
    }
}

fn compile_shader(src: &str, ty: GLenum) -> GLuint {
    log_debug(
        "compile_shader",
        &format!("start type=0x{:X}, src_len={}", ty, src.len()),
    );
    unsafe {
        let shader = gl::CreateShader(ty);
        log_debug("compile_shader", &format!("CreateShader -> {}", shader));
        let c_src = CString::new(src).unwrap();
        let src_ptr = c_src.as_ptr();
        let len = src.len() as GLint;

        gl::ShaderSource(shader, 1, &src_ptr, &len);
        gl::CompileShader(shader);

        let mut status: GLint = 0;
        gl::GetShaderiv(shader, gl::COMPILE_STATUS, &mut status);
        log_debug("compile_shader", &format!("COMPILE_STATUS={}", status));
        if status == 0 {
            let mut log_len: GLint = 0;
            gl::GetShaderiv(shader, gl::INFO_LOG_LENGTH, &mut log_len);
            if log_len > 0 {
                let mut buffer = vec![0u8; log_len as usize];
                gl::GetShaderInfoLog(
                    shader,
                    log_len,
                    ptr::null_mut(),
                    buffer.as_mut_ptr() as *mut i8,
                );
                log_debug(
                    "compile_shader",
                    &format!("compile error: {}", String::from_utf8_lossy(&buffer)),
                );
            }
        }

        shader
    }
}

fn link_program(vs: GLuint, fs: GLuint) -> GLuint {
    log_debug("link_program", &format!("start vs={}, fs={}", vs, fs));
    unsafe {
        let program = gl::CreateProgram();
        gl::AttachShader(program, vs);
        gl::AttachShader(program, fs);
        gl::LinkProgram(program);

        let mut status: GLint = 0;
        gl::GetProgramiv(program, gl::LINK_STATUS, &mut status);
        log_debug("link_program", &format!("LINK_STATUS={}", status));
        if status == 0 {
            let mut log_len: GLint = 0;
            gl::GetProgramiv(program, gl::INFO_LOG_LENGTH, &mut log_len);
            if log_len > 0 {
                let mut buffer = vec![0u8; log_len as usize];
                gl::GetProgramInfoLog(
                    program,
                    log_len,
                    ptr::null_mut(),
                    buffer.as_mut_ptr() as *mut i8,
                );
                log_debug(
                    "link_program",
                    &format!("link error: {}", String::from_utf8_lossy(&buffer)),
                );
            }
        }

        program
    }
}

fn init_shader() {
    log_debug("init_shader", "start");
    unsafe {
        gl::GenBuffers(2, &mut VBO[0]);
        log_debug(
            "init_shader",
            &format!("GenBuffers -> [{}, {}]", VBO[0], VBO[1]),
        );

        gl::BindBuffer(gl::ARRAY_BUFFER, VBO[0]);
        gl::BufferData(
            gl::ARRAY_BUFFER,
            (VERTEX_DATA.len() * mem::size_of::<GLfloat>()) as GLsizeiptr,
            VERTEX_DATA.as_ptr() as *const _,
            gl::STATIC_DRAW,
        );

        gl::BindBuffer(gl::ARRAY_BUFFER, VBO[1]);
        gl::BufferData(
            gl::ARRAY_BUFFER,
            (COLOR_DATA.len() * mem::size_of::<GLfloat>()) as GLsizeiptr,
            COLOR_DATA.as_ptr() as *const _,
            gl::STATIC_DRAW,
        );

        let vs = compile_shader(VS_SRC, gl::VERTEX_SHADER);
        let fs = compile_shader(FS_SRC, gl::FRAGMENT_SHADER);
        let program = link_program(vs, fs);
        gl::UseProgram(program);
        log_debug("init_shader", &format!("UseProgram({})", program));

        let pos_name = CString::new("position").unwrap();
        POS_ATTR = gl::GetAttribLocation(program, pos_name.as_ptr());
        let pos_attr = POS_ATTR;
        log_debug("init_shader", &format!("position attrib={}", pos_attr));
        if POS_ATTR >= 0 {
            gl::EnableVertexAttribArray(POS_ATTR as GLuint);
        }

        let col_name = CString::new("color").unwrap();
        COL_ATTR = gl::GetAttribLocation(program, col_name.as_ptr());
        let col_attr = COL_ATTR;
        log_debug("init_shader", &format!("color attrib={}", col_attr));
        if COL_ATTR >= 0 {
            gl::EnableVertexAttribArray(COL_ATTR as GLuint);
        }

        gl::DeleteShader(vs);
        gl::DeleteShader(fs);
    }
    log_debug("init_shader", "end");
}

fn draw_triangle() {
    unsafe {
        FRAME_COUNT = FRAME_COUNT.wrapping_add(1);
        if FRAME_COUNT <= 5 {
            let frame = FRAME_COUNT;
            let pos_attr = POS_ATTR;
            let col_attr = COL_ATTR;
            log_debug(
                "draw_triangle",
                &format!(
                    "frame={}, pos_attr={}, col_attr={}",
                    frame, pos_attr, col_attr
                ),
            );
        }

        if POS_ATTR >= 0 {
            gl::BindBuffer(gl::ARRAY_BUFFER, VBO[0]);
            gl::VertexAttribPointer(POS_ATTR as GLuint, 3, gl::FLOAT, gl::FALSE, 0, ptr::null());
        }

        if COL_ATTR >= 0 {
            gl::BindBuffer(gl::ARRAY_BUFFER, VBO[1]);
            gl::VertexAttribPointer(COL_ATTR as GLuint, 3, gl::FLOAT, gl::FALSE, 0, ptr::null());
        }

        gl::Clear(gl::COLOR_BUFFER_BIT);
        gl::DrawArrays(gl::TRIANGLES, 0, 3);
    }
}

extern "system" fn window_proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> isize {
    unsafe {
        if msg == WM_CLOSE || msg == WM_DESTROY || msg == WM_SIZE {
            log_debug(
                "window_proc",
                &format!("msg=0x{:X}, wparam={}, lparam=0x{:X}", msg, wparam, lparam),
            );
        }
        match msg {
            WM_CLOSE => {
                SHOULD_CLOSE = true;
                PostQuitMessage(0);
                0
            }
            WM_SIZE => {
                let width = (lparam as u32 & 0xFFFF) as i32;
                let height = ((lparam as u32 >> 16) & 0xFFFF) as i32;
                if GL_READY && width > 0 && height > 0 {
                    gl::Viewport(0, 0, width, height);
                    log_debug("window_proc", &format!("Viewport({}, {})", width, height));
                } else {
                    log_debug(
                        "window_proc",
                        &format!("WM_SIZE ignored before GL ready ({}, {})", width, height),
                    );
                }
                0
            }
            WM_DESTROY => 0,
            _ => DefWindowProcA(hwnd, msg, wparam, lparam),
        }
    }
}

fn load_gl_functions() {
    let gl_lib: HMODULE = unsafe { LoadLibraryA(b"opengl32.dll\0".as_ptr() as *const i8) };
    log_debug("load_gl_functions", &format!("LoadLibraryA(opengl32.dll) -> {:p}", gl_lib));
    gl::load_with(|name| {
        let c_name = CString::new(name).unwrap();
        let wgl_ptr = unsafe { wglGetProcAddress(c_name.as_ptr() as *const i8) } as *const c_void;
        if !wgl_ptr.is_null() {
            wgl_ptr
        } else if !gl_lib.is_null() {
            unsafe { GetProcAddress(gl_lib, c_name.as_ptr() as *const i8) as *const _ }
        } else {
            ptr::null()
        }
    });
    log_debug("load_gl_functions", "gl::load_with completed");
}

fn enable_opengl(hdc: *mut HDC) -> HGLRC {
    log_debug("enable_opengl", &format!("start hdc={:p}", unsafe { *hdc }));
    unsafe {
        let mut pfd: PIXELFORMATDESCRIPTOR = mem::zeroed();
        pfd.nSize = mem::size_of::<PIXELFORMATDESCRIPTOR>() as u16;
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 24;
        pfd.cDepthBits = 16;
        pfd.iLayerType = PFD_MAIN_PLANE;

        let pixel_format = ChoosePixelFormat(*hdc, &pfd);
        log_debug("enable_opengl", &format!("ChoosePixelFormat -> {}", pixel_format));
        if pixel_format == 0 {
            log_debug(
                "enable_opengl",
                &format!("ChoosePixelFormat failed, GetLastError={}", GetLastError()),
            );
        }
        if SetPixelFormat(*hdc, pixel_format, &pfd) == 0 {
            log_debug(
                "enable_opengl",
                &format!("SetPixelFormat failed, GetLastError={}", GetLastError()),
            );
        }

        // Create a temporary legacy context to fetch WGL extension functions.
        let legacy_ctx = wglCreateContext(*hdc);
        log_debug("enable_opengl", &format!("legacy_ctx={:p}", legacy_ctx));
        if legacy_ctx.is_null() {
            log_debug(
                "enable_opengl",
                &format!("wglCreateContext failed, GetLastError={}", GetLastError()),
            );
            return ptr::null_mut();
        }
        wglMakeCurrent(*hdc, legacy_ctx);

        let create_ctx_ptr = wglGetProcAddress(b"wglCreateContextAttribsARB\0".as_ptr() as *const i8);
        log_debug(
            "enable_opengl",
            &format!("wglCreateContextAttribsARB ptr={:p}", create_ctx_ptr),
        );

        let hglrc = if !create_ctx_ptr.is_null() {
            let wgl_create_context_attribs_arb: extern "system" fn(HDC, HGLRC, *const i32) -> HGLRC =
                mem::transmute(create_ctx_ptr);

            let es2_attribs = [
                WGL_CONTEXT_MAJOR_VERSION_ARB,
                2,
                WGL_CONTEXT_MINOR_VERSION_ARB,
                0,
                WGL_CONTEXT_FLAGS_ARB,
                0,
                WGL_CONTEXT_PROFILE_MASK_ARB,
                WGL_CONTEXT_ES2_PROFILE_BIT_EXT,
                0,
            ];

            let es2_ctx = wgl_create_context_attribs_arb(*hdc, ptr::null_mut(), es2_attribs.as_ptr());
            if !es2_ctx.is_null() {
                log_debug("enable_opengl", &format!("es2_ctx={:p}", es2_ctx));
                es2_ctx
            } else {
                log_debug(
                    "enable_opengl",
                    &format!("ES2 context creation failed, GetLastError={}", GetLastError()),
                );
                legacy_ctx
            }
        } else {
            log_debug("enable_opengl", "wglCreateContextAttribsARB unavailable, use legacy context");
            legacy_ctx
        };

        if hglrc != legacy_ctx {
            wglMakeCurrent(*hdc, hglrc);
            wglDeleteContext(legacy_ctx);
            log_debug("enable_opengl", "switched from legacy context to ES2 context");
        }

        load_gl_functions();
        log_debug(
            "enable_opengl",
            &format!(
                "GL_VERSION={}, GLSL={}",
                gl_string(gl::VERSION),
                gl_string(gl::SHADING_LANGUAGE_VERSION)
            ),
        );
        log_debug("enable_opengl", &format!("end context={:p}", hglrc));
        hglrc
    }
}

fn disable_opengl(hwnd: HWND, hdc: *mut HDC, hglrc: HGLRC) {
    log_debug(
        "disable_opengl",
        &format!("start hwnd={:p}, hdc={:p}, hglrc={:p}", hwnd, unsafe { *hdc }, hglrc),
    );
    unsafe {
        wglMakeCurrent(ptr::null_mut(), ptr::null_mut());
        wglDeleteContext(hglrc);
        ReleaseDC(hwnd, *hdc);
    }
    log_debug("disable_opengl", "end");
}

fn main() {
    log_debug("main", "start");
    unsafe {
        let hinstance = GetModuleHandleA(ptr::null());
        log_debug("main", &format!("GetModuleHandleA -> {:p}", hinstance));

        let class_name = b"OpenGLES2Window\0";
        let window_name = b"OpenGL ES 2.0 Triangle (Win32 API)\0";

        let wc = WNDCLASSA {
            style: CS_OWNDC,
            lpfnWndProc: Some(window_proc),
            cbClsExtra: 0,
            cbWndExtra: 0,
            hInstance: hinstance as *mut _,
            hIcon: LoadIconA(ptr::null_mut(), ptr::null()),
            hCursor: LoadCursorA(ptr::null_mut(), ptr::null()),
            hbrBackground: ptr::null_mut(),
            lpszMenuName: ptr::null(),
            lpszClassName: class_name.as_ptr() as *const i8,
        };

        let class_atom = RegisterClassA(&wc);
        log_debug("main", &format!("RegisterClassA -> {}", class_atom));
        if class_atom == 0 {
            log_debug(
                "main",
                &format!("RegisterClassA failed, GetLastError={}", GetLastError()),
            );
            return;
        }

        let hwnd = CreateWindowExA(
            0,
            class_name.as_ptr() as *const i8,
            window_name.as_ptr() as *const i8,
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            640,
            480,
            ptr::null_mut(),
            ptr::null_mut(),
            hinstance as *mut _,
            ptr::null_mut(),
        );
        log_debug("main", &format!("CreateWindowExA -> {:p}", hwnd));
        if hwnd.is_null() {
            log_debug(
                "main",
                &format!("CreateWindowExA failed, GetLastError={}", GetLastError()),
            );
            return;
        }

        let mut hdc = GetDC(hwnd);
        log_debug("main", &format!("GetDC -> {:p}", hdc));
        if hdc.is_null() {
            log_debug("main", &format!("GetDC failed, GetLastError={}", GetLastError()));
            return;
        }

        let hglrc = enable_opengl(&mut hdc);
        log_debug("main", &format!("enable_opengl -> {:p}", hglrc));
        if hglrc.is_null() {
            log_debug("main", "enable_opengl returned NULL context");
            return;
        }

        init_shader();
        gl::ClearColor(0.0, 0.0, 0.0, 0.0);
        gl::Viewport(0, 0, 640, 480);
        GL_READY = true;
        log_debug("main", "clear color and viewport initialized");

        let mut msg: MSG = mem::zeroed();
        log_debug("main", "enter message loop");
        while !SHOULD_CLOSE {
            if PeekMessageA(&mut msg, ptr::null_mut(), 0, 0, PM_REMOVE) > 0 {
                if msg.message == WM_QUIT {
                    log_debug("main", "received WM_QUIT");
                    break;
                }
                TranslateMessage(&msg);
                DispatchMessageA(&msg);
            } else {
                draw_triangle();
                SwapBuffers(hdc);
            }
        }
        log_debug("main", "leave message loop");

        disable_opengl(hwnd, &mut hdc, hglrc);
        DestroyWindow(hwnd);
        log_debug("main", "end");
    }
}
