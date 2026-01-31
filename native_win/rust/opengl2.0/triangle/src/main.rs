#![windows_subsystem = "windows"]

use gl::types::*;
use std::ffi::CString;
use std::mem;
use std::ptr;
use winapi::shared::minwindef::{LPARAM, WPARAM};
use winapi::shared::windef::{HWND, HDC, HGLRC};
use winapi::um::winuser::*;
use winapi::um::wingdi::*;
use winapi::um::libloaderapi::GetModuleHandleA;

// Vertex data
static VERTEX_DATA: [GLfloat; 9] = [
    0.0, 0.5, 0.0,
    0.5, -0.5, 0.0,
    -0.5, -0.5, 0.0,
];

// Color data
static COLOR_DATA: [GLfloat; 9] = [
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0,
];

// Shader sources
static VS_SRC: &str = 
   "attribute vec3 position;                     \n\
    attribute vec3 color;                        \n\
    varying vec4 vColor;                         \n\
    void main() {                                \n\
       vColor = vec4(color, 1.0);                \n\
       gl_Position = vec4(position, 1.0);        \n\
    }";

static FS_SRC: &str = 
   "varying vec4 vColor;                         \n\
    void main() {                                \n\
       gl_FragColor = vColor;                    \n\
    }";

static mut SHOULD_CLOSE: bool = false;
static mut VBO: [GLuint; 2] = [0, 0];
static mut POS_ATTR: GLint = 0;
static mut COL_ATTR: GLint = 0;

fn compile_shader(src: &str, ty: GLenum) -> GLuint {
    unsafe {
        let shader = gl::CreateShader(ty);
        let c_src = CString::new(src).unwrap();
        let ptr = c_src.as_ptr();
        let len = src.len() as GLint;
        gl::ShaderSource(shader, 1, &ptr, &len);
        gl::CompileShader(shader);

        let mut status = gl::FALSE as GLint;
        gl::GetShaderiv(shader, gl::COMPILE_STATUS, &mut status);
        if status == 0 {
            let mut len = 0;
            gl::GetShaderiv(shader, gl::INFO_LOG_LENGTH, &mut len);
            let mut buffer = vec![0u8; len as usize];
            gl::GetShaderInfoLog(shader, len, ptr::null_mut(), buffer.as_mut_ptr() as *mut i8);
            eprintln!("Shader compile error: {:?}", String::from_utf8_lossy(&buffer));
        }

        shader
    }
}

fn link_program(vs: GLuint, fs: GLuint) -> GLuint {
    unsafe {
        let program = gl::CreateProgram();
        gl::AttachShader(program, vs);
        gl::AttachShader(program, fs);
        gl::LinkProgram(program);

        let mut status = gl::FALSE as GLint;
        gl::GetProgramiv(program, gl::LINK_STATUS, &mut status);
        if status == 0 {
            let mut len = 0;
            gl::GetProgramiv(program, gl::INFO_LOG_LENGTH, &mut len);
            let mut buffer = vec![0u8; len as usize];
            gl::GetProgramInfoLog(program, len, ptr::null_mut(), buffer.as_mut_ptr() as *mut i8);
            eprintln!("Program link error: {:?}", String::from_utf8_lossy(&buffer));
        }

        program
    }
}

fn init_shader() {
    unsafe {
        gl::GenBuffers(2, &mut VBO[0]);

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

        // Compile shaders
        let vs = compile_shader(VS_SRC, gl::VERTEX_SHADER);
        let fs = compile_shader(FS_SRC, gl::FRAGMENT_SHADER);
        let program = link_program(vs, fs);

        gl::UseProgram(program);

        // Set up vertex attributes
        let pos_cstr = CString::new("position").unwrap();
        POS_ATTR = gl::GetAttribLocation(program, pos_cstr.as_ptr());
        gl::EnableVertexAttribArray(POS_ATTR as GLuint);

        let col_cstr = CString::new("color").unwrap();
        COL_ATTR = gl::GetAttribLocation(program, col_cstr.as_ptr());
        gl::EnableVertexAttribArray(COL_ATTR as GLuint);

        gl::DeleteShader(vs);
        gl::DeleteShader(fs);
        
        // Set clear color
        gl::ClearColor(0.0, 0.0, 0.0, 1.0);
    }
}

fn draw_triangle() {
    unsafe {
        gl::BindBuffer(gl::ARRAY_BUFFER, VBO[0]);
        gl::VertexAttribPointer(POS_ATTR as GLuint, 3, gl::FLOAT, gl::FALSE as u8, 0, ptr::null());

        gl::BindBuffer(gl::ARRAY_BUFFER, VBO[1]);
        gl::VertexAttribPointer(COL_ATTR as GLuint, 3, gl::FLOAT, gl::FALSE as u8, 0, ptr::null());

        gl::Clear(gl::COLOR_BUFFER_BIT);
        gl::DrawArrays(gl::TRIANGLES, 0, 3);
    }
}

extern "system" fn window_proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> isize {
    unsafe {
        match msg {
            WM_CREATE => {
                eprintln!("[DEBUG] WM_CREATE received");
                0
            }
            WM_CLOSE => {
                eprintln!("[DEBUG] WM_CLOSE received");
                SHOULD_CLOSE = true;
                PostQuitMessage(0);
                0
            }
            WM_DESTROY => {
                eprintln!("[DEBUG] WM_DESTROY received");
                0
            }
            _ => DefWindowProcA(hwnd, msg, wparam, lparam),
        }
    }
}

fn enable_opengl(_hwnd: HWND, hdc: *mut HDC) -> HGLRC {
    unsafe {
        eprintln!("[DEBUG] enable_opengl: Starting");
        let mut pfd: PIXELFORMATDESCRIPTOR = mem::zeroed();
        pfd.nSize = mem::size_of::<PIXELFORMATDESCRIPTOR>() as u16;
        pfd.nVersion = 1;
        pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
        pfd.iPixelType = PFD_TYPE_RGBA;
        pfd.cColorBits = 24;
        pfd.cDepthBits = 16;
        pfd.iLayerType = PFD_MAIN_PLANE;

        let iformat = ChoosePixelFormat(*hdc, &pfd);
        eprintln!("[DEBUG] enable_opengl: ChoosePixelFormat returned {}", iformat);
        SetPixelFormat(*hdc, iformat, &pfd);

        let hglrc_old = wglCreateContext(*hdc);
        eprintln!("[DEBUG] enable_opengl: wglCreateContext (old) returned {:p}", hglrc_old);
        wglMakeCurrent(*hdc, hglrc_old);

        // Get wglCreateContextAttribsARB function
        let wgl_create_context_attribs_arb_ptr = wglGetProcAddress(b"wglCreateContextAttribsARB\0".as_ptr() as *const i8);
        eprintln!("[DEBUG] enable_opengl: wglGetProcAddress returned {:p}", wgl_create_context_attribs_arb_ptr);
        
        // Create OpenGL 2.0 context
        let hglrc = if !wgl_create_context_attribs_arb_ptr.is_null() {
            eprintln!("[DEBUG] enable_opengl: Attempting to create OpenGL 2.0 context");
            let wgl_create_context_attribs_arb: extern "system" fn(*mut HDC, HGLRC, *const i32) -> HGLRC =
                mem::transmute(wgl_create_context_attribs_arb_ptr);
            
            let attribs = [
                0x2091i32, 2,    // WGL_CONTEXT_MAJOR_VERSION_ARB
                0x2092i32, 0,    // WGL_CONTEXT_MINOR_VERSION_ARB
                0,
            ];
            let new_context = wgl_create_context_attribs_arb(hdc, ptr::null_mut() as HGLRC, attribs.as_ptr());
            
            if !new_context.is_null() {
                eprintln!("[DEBUG] enable_opengl: OpenGL 2.0 context created successfully");
                new_context
            } else {
                eprintln!("[DEBUG] enable_opengl: OpenGL 2.0 context creation failed, using old context");
                hglrc_old
            }
        } else {
            eprintln!("[DEBUG] enable_opengl: wglCreateContextAttribsARB not available, using old context");
            hglrc_old
        };

        eprintln!("[DEBUG] enable_opengl: Final context: {:p}", hglrc);
        
        // Only switch contexts if we got a new one
        if hglrc != hglrc_old {
            wglMakeCurrent(*hdc, hglrc);
            wglDeleteContext(hglrc_old);
        }

        // Load OpenGL functions
        eprintln!("[DEBUG] enable_opengl: Loading OpenGL functions");
        gl::load_with(|s| {
            let cstr = CString::new(s).unwrap();
            mem::transmute(wglGetProcAddress(cstr.as_ptr() as *const i8))
        });
        eprintln!("[DEBUG] enable_opengl: OpenGL functions loaded");

        // Load OpenGL functions
        gl::load_with(|s| {
            let cstr = CString::new(s).unwrap();
            mem::transmute(wglGetProcAddress(cstr.as_ptr() as *const i8))
        });

        hglrc
    }
}

fn disable_opengl(hwnd: HWND, hdc: *mut HDC, hglrc: HGLRC) {
    unsafe {
        wglMakeCurrent(ptr::null_mut(), ptr::null_mut());
        wglDeleteContext(hglrc);
        ReleaseDC(hwnd, *hdc);
    }
}

fn main() {
    eprintln!("[DEBUG] Application started");
    unsafe {
        let hinstance = GetModuleHandleA(ptr::null());

        let class_name = b"OpenGLWindow\0";
        let window_name = b"OpenGL 2.0 Triangle (Win32 API)\0";

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

        RegisterClassA(&wc);

        let hwnd = CreateWindowExA(
            0,
            class_name.as_ptr() as *const i8,
            window_name.as_ptr() as *const i8,
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            100,
            100,
            800,
            600,
            ptr::null_mut(),
            ptr::null_mut(),
            hinstance as *mut _,
            ptr::null_mut(),
        );

        eprintln!("[DEBUG] Window created: {:p}", hwnd);

        let mut hdc = GetDC(hwnd);
        eprintln!("[DEBUG] Device context obtained: {:p}", hdc);
        let hglrc = enable_opengl(hwnd, &mut hdc);
        eprintln!("[DEBUG] OpenGL context created: {:p}", hglrc);

        init_shader();
        eprintln!("[DEBUG] Shader initialized, POS_ATTR={}, COL_ATTR={}", POS_ATTR, COL_ATTR);

        eprintln!("[DEBUG] Entering message loop");
        let mut msg: MSG = mem::zeroed();

        while !SHOULD_CLOSE {
            if PeekMessageA(&mut msg, ptr::null_mut(), 0, 0, PM_REMOVE) > 0 {
                if msg.message == WM_QUIT {
                    eprintln!("WM_QUIT received");
                    break;
                }
                TranslateMessage(&msg);
                DispatchMessageA(&msg);
            }
            
            draw_triangle();
            SwapBuffers(hdc);
        }

        eprintln!("Message loop exited");
        disable_opengl(hwnd, &mut hdc, hglrc);
        eprintln!("OpenGL disabled");
        DestroyWindow(hwnd);
        eprintln!("Window destroyed");
    }
}
