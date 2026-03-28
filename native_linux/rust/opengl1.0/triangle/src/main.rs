use std::ffi::CString;
use std::ptr;
use x11::{glx, xlib};

// Immediate-mode functions removed from core profile; link directly to libGL
extern "C" {
    fn glBegin(mode: u32);
    fn glEnd();
    fn glColor3f(r: f32, g: f32, b: f32);
    fn glVertex2f(x: f32, y: f32);
}

fn render() {
    unsafe {
        gl::Clear(gl::COLOR_BUFFER_BIT);
        glBegin(gl::TRIANGLES);
        glColor3f(1.0, 0.0, 0.0); glVertex2f( 0.0,  0.5);
        glColor3f(0.0, 1.0, 0.0); glVertex2f( 0.5, -0.5);
        glColor3f(0.0, 0.0, 1.0); glVertex2f(-0.5, -0.5);
        glEnd();
    }
}

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

        let context = glx::glXCreateNewContext(display, best_fbc, glx::GLX_RGBA_TYPE, ptr::null_mut(), 1);
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
                        glx::glXDestroyContext(display, context);
                        xlib::XDestroyWindow(display, window);
                        xlib::XCloseDisplay(display);
                        return;
                    }
                }
            }
            render();
            glx::glXSwapBuffers(display, window);
        }
    }
}
