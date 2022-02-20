#![windows_subsystem = "windows"]

extern crate gl;
extern crate glfw;

use windows::Win32::Graphics::OpenGL::*;
use core::ffi::c_void;
use gl::types::*;
use glfw::Context;

// Vertex data
static VERTEX_DATA: [GLfloat;9] = [
     0.0,  0.5,  0.0,
     0.5, -0.5,  0.0,
    -0.5, -0.5,  0.0
];

// Color data
static COLOR_DATA: [GLfloat;9] = [
     1.0, 0.0, 0.0,
     0.0, 1.0, 0.0,
     0.0, 0.0, 1.0
];

fn main() {
    unsafe {
        let mut glfw = glfw::init(glfw::FAIL_ON_ERRORS).unwrap();
        glfw.window_hint(glfw::WindowHint::ContextVersion(1, 1));
        let (mut window, _) = glfw.create_window(640, 480, "Hello, World!", glfw::WindowMode::Windowed).expect("Failed");
        window.make_current();
        gl::load_with(|s| window.get_proc_address(s));

        while !window.should_close() {
            glfw.poll_events();

            glEnableClientState(GL_COLOR_ARRAY);
            glEnableClientState(GL_VERTEX_ARRAY);

            glVertexPointer(3, GL_FLOAT, 0, VERTEX_DATA.as_ptr() as *mut c_void);
            glColorPointer (3, GL_FLOAT, 0, COLOR_DATA.as_ptr()  as *mut c_void);

            gl::DrawArrays(gl::TRIANGLES, 0, 3);

            window.swap_buffers();
        }
    }
}