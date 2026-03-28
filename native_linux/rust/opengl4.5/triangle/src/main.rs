use std::ffi::CString;
use std::ptr;
use x11::{glx, xlib};

type GlXCreateContextAttribsARBFn = unsafe extern "C" fn(
    *mut xlib::Display,
    glx::GLXFBConfig,
    glx::GLXContext,
    xlib::Bool,
    *const i32,
) -> glx::GLXContext;

fn compile_shader(src: &str, kind: gl::types::GLenum) -> u32 {
    unsafe {
        let shader = gl::CreateShader(kind);
        let c_src = CString::new(src).unwrap();
        gl::ShaderSource(shader, 1, &c_src.as_ptr(), ptr::null());
        gl::CompileShader(shader);
        let mut status = 0i32;
        gl::GetShaderiv(shader, gl::COMPILE_STATUS, &mut status);
        if status == 0 {
            let mut len = 0i32;
            gl::GetShaderiv(shader, gl::INFO_LOG_LENGTH, &mut len);
            let mut buf = vec![0u8; len as usize];
            gl::GetShaderInfoLog(shader, len, ptr::null_mut(), buf.as_mut_ptr() as *mut _);
            eprintln!("Shader compile error: {}", String::from_utf8_lossy(&buf));
        }
        shader
    }
}

fn link_program(vert: u32, frag: u32) -> u32 {
    unsafe {
        let program = gl::CreateProgram();
        gl::AttachShader(program, vert);
        gl::AttachShader(program, frag);
        gl::LinkProgram(program);
        let mut status = 0i32;
        gl::GetProgramiv(program, gl::LINK_STATUS, &mut status);
        if status == 0 {
            let mut len = 0i32;
            gl::GetProgramiv(program, gl::INFO_LOG_LENGTH, &mut len);
            let mut buf = vec![0u8; len as usize];
            gl::GetProgramInfoLog(program, len, ptr::null_mut(), buf.as_mut_ptr() as *mut _);
            eprintln!("Program link error: {}", String::from_utf8_lossy(&buf));
        }
        program
    }
}

fn render(vao: u32) {
    unsafe {
        gl::Clear(gl::COLOR_BUFFER_BIT);
        gl::BindVertexArray(vao);
        gl::DrawArrays(gl::TRIANGLES, 0, 3);
        gl::BindVertexArray(0);
    }
}

const VERT_SRC: &str = "#version 450 core
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
out vec4 vColor;
void main() {
  vColor = vec4(color, 1.0);
  gl_Position = vec4(position, 1.0);
}";

const FRAG_SRC: &str = "#version 450 core
in  vec4 vColor;
out vec4 outColor;
void main() {
  outColor = vColor;
}";

fn main() {
    unsafe {
        let display = xlib::XOpenDisplay(ptr::null());
        if display.is_null() {
            eprintln!("Cannot open display");
            return;
        }
        let screen = xlib::XDefaultScreen(display);
        let root = xlib::XRootWindow(display, screen);

        let mut glx_major = 0i32;
        let mut glx_minor = 0i32;
        if glx::glXQueryVersion(display, &mut glx_major, &mut glx_minor) == 0 {
            eprintln!("GLX not available");
            xlib::XCloseDisplay(display);
            return;
        }

        let fb_attribs: [i32; 23] = [
            glx::GLX_X_RENDERABLE,  1,
            glx::GLX_DRAWABLE_TYPE, glx::GLX_WINDOW_BIT,
            glx::GLX_RENDER_TYPE,   glx::GLX_RGBA_BIT,
            glx::GLX_X_VISUAL_TYPE, glx::GLX_TRUE_COLOR,
            glx::GLX_RED_SIZE,      8,
            glx::GLX_GREEN_SIZE,    8,
            glx::GLX_BLUE_SIZE,     8,
            glx::GLX_ALPHA_SIZE,    8,
            glx::GLX_DEPTH_SIZE,    24,
            glx::GLX_STENCIL_SIZE,  8,
            glx::GLX_DOUBLEBUFFER,  1,
            0,
        ];

        let mut fb_count = 0i32;
        let fbc = glx::glXChooseFBConfig(display, screen, fb_attribs.as_ptr(), &mut fb_count);
        if fbc.is_null() || fb_count == 0 {
            eprintln!("Failed to retrieve FBConfig");
            xlib::XCloseDisplay(display);
            return;
        }

        let mut best_fbc_idx = 0i32;
        let mut best_num_samp = -1i32;
        for i in 0..fb_count {
            let vi = glx::glXGetVisualFromFBConfig(display, *fbc.offset(i as isize));
            if !vi.is_null() {
                let mut samp_buf = 0i32;
                let mut samples = 0i32;
                glx::glXGetFBConfigAttrib(display, *fbc.offset(i as isize), glx::GLX_SAMPLE_BUFFERS, &mut samp_buf);
                glx::glXGetFBConfigAttrib(display, *fbc.offset(i as isize), glx::GLX_SAMPLES, &mut samples);
                if samp_buf > 0 && samples > best_num_samp {
                    best_fbc_idx = i;
                    best_num_samp = samples;
                }
                xlib::XFree(vi as *mut _);
            }
        }
        let best_fbc = *fbc.offset(best_fbc_idx as isize);
        xlib::XFree(fbc as *mut _);

        let vi = glx::glXGetVisualFromFBConfig(display, best_fbc);
        if vi.is_null() {
            eprintln!("Failed to get visual");
            xlib::XCloseDisplay(display);
            return;
        }

        let colormap = xlib::XCreateColormap(display, root, (*vi).visual, xlib::AllocNone);
        let mut swa: xlib::XSetWindowAttributes = std::mem::zeroed();
        swa.colormap = colormap;
        swa.border_pixel = 0;
        swa.event_mask = xlib::ExposureMask;

        let window = xlib::XCreateWindow(
            display, root,
            0, 0, 640, 480, 0,
            (*vi).depth,
            xlib::InputOutput as u32,
            (*vi).visual,
            xlib::CWBorderPixel | xlib::CWColormap | xlib::CWEventMask,
            &mut swa,
        );
        xlib::XFree(vi as *mut _);

        let title = CString::new("Hello, World!").unwrap();
        xlib::XStoreName(display, window, title.as_ptr());

        let atom_name = CString::new("WM_DELETE_WINDOW").unwrap();
        let wm_delete_window = xlib::XInternAtom(display, atom_name.as_ptr(), xlib::False);
        let mut protocols = [wm_delete_window];
        xlib::XSetWMProtocols(display, window, protocols.as_mut_ptr(), 1);

        let fn_name = CString::new("glXCreateContextAttribsARB").unwrap();
        let create_ctx_fn = glx::glXGetProcAddress(fn_name.as_ptr() as *const u8);

        let context = if let Some(f) = create_ctx_fn {
            let create_ctx: GlXCreateContextAttribsARBFn = std::mem::transmute(f);
            let attribs = [
                0x2091i32, 4,
                0x2092i32, 5,
                0x9126i32, 0x00000001i32,
                0i32,
            ];
            create_ctx(display, best_fbc, std::ptr::null_mut(), 1, attribs.as_ptr())
        } else {
            glx::glXCreateNewContext(display, best_fbc, glx::GLX_RGBA_TYPE, std::ptr::null_mut(), 1)
        };
        if context.is_null() {
            eprintln!("Failed to create GL context");
            xlib::XDestroyWindow(display, window);
            xlib::XCloseDisplay(display);
            return;
        }

        glx::glXMakeCurrent(display, window, context);

        gl::load_with(|s| {
            let c_str = CString::new(s).unwrap();
            let ptr = glx::glXGetProcAddress(c_str.as_ptr() as *const u8);
            ptr.map(|f| f as *const _).unwrap_or(std::ptr::null())
        });

        let vert = compile_shader(VERT_SRC, gl::VERTEX_SHADER);
        let frag = compile_shader(FRAG_SRC, gl::FRAGMENT_SHADER);
        let program = link_program(vert, frag);
        gl::UseProgram(program);

        let vertices: [f32; 9] = [0.0, 0.5, 0.0,  0.5, -0.5, 0.0,  -0.5, -0.5, 0.0];
        let colors:   [f32; 9] = [1.0, 0.0, 0.0,  0.0,  1.0, 0.0,   0.0,  0.0, 1.0];

        let mut vao = 0u32;
        gl::GenVertexArrays(1, &mut vao);
        gl::BindVertexArray(vao);

        let mut vbo = [0u32; 2];
        gl::GenBuffers(2, vbo.as_mut_ptr());

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[0]);
        gl::BufferData(gl::ARRAY_BUFFER, (vertices.len() * std::mem::size_of::<f32>()) as isize, vertices.as_ptr() as *const _, gl::STATIC_DRAW);
        gl::VertexAttribPointer(0, 3, gl::FLOAT, gl::FALSE, 0, std::ptr::null());
        gl::EnableVertexAttribArray(0);

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[1]);
        gl::BufferData(gl::ARRAY_BUFFER, (colors.len() * std::mem::size_of::<f32>()) as isize, colors.as_ptr() as *const _, gl::STATIC_DRAW);
        gl::VertexAttribPointer(1, 3, gl::FLOAT, gl::FALSE, 0, std::ptr::null());
        gl::EnableVertexAttribArray(1);

        gl::BindVertexArray(0);

        gl::ClearColor(0.0, 0.0, 0.0, 1.0);
        gl::Viewport(0, 0, 640, 480);

        xlib::XMapRaised(display, window);

        let mut event: xlib::XEvent = std::mem::zeroed();
        loop {
            while xlib::XPending(display) > 0 {
                xlib::XNextEvent(display, &mut event);
                if event.type_ == xlib::ClientMessage {
                    let xclient = event.client_message;
                    if xclient.data.as_longs()[0] as u64 == wm_delete_window {
                        gl::DeleteVertexArrays(1, &vao);
                        gl::DeleteBuffers(2, vbo.as_ptr());
                        gl::DeleteProgram(program);
                        gl::DeleteShader(vert);
                        gl::DeleteShader(frag);
                        glx::glXDestroyContext(display, context);
                        xlib::XDestroyWindow(display, window);
                        xlib::XCloseDisplay(display);
                        return;
                    }
                }
            }
            render(vao);
            glx::glXSwapBuffers(display, window);
        }
    }
}
