extern crate gl;
extern crate glfw;

use gl::types::*;
use glfw::Context;
use core::ffi::c_void;

#[link(name = "GL")]
extern "C" {
    fn glEnableClientState(cap: u32);
    fn glVertexPointer(size: i32, type_: u32, stride: i32, ptr: *const c_void);
    fn glColorPointer(size: i32, type_: u32, stride: i32, ptr: *const c_void);
}

const GL_VERTEX_ARRAY: u32 = 0x8074;
const GL_COLOR_ARRAY:  u32 = 0x8076;

static VERTEX_DATA: [GLfloat; 9] = [
     0.0,  0.5,  0.0,
     0.5, -0.5,  0.0,
    -0.5, -0.5,  0.0,
];

static COLOR_DATA: [GLfloat; 9] = [
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0,
];

fn main() {
    let mut glfw = glfw::init(glfw::fail_on_errors).unwrap();
    glfw.window_hint(glfw::WindowHint::ContextVersion(1, 1));
    let (mut window, _) = glfw
        .create_window(640, 480, "Hello, World!", glfw::WindowMode::Windowed)
        .expect("Failed to create GLFW window");
    window.make_current();
    gl::load_with(|s| window.get_proc_address(s) as *const _);

    while !window.should_close() {
        glfw.poll_events();
        unsafe {
            glEnableClientState(GL_COLOR_ARRAY);
            glEnableClientState(GL_VERTEX_ARRAY);
            glVertexPointer(3, gl::FLOAT, 0, VERTEX_DATA.as_ptr() as *const c_void);
            glColorPointer(3, gl::FLOAT, 0, COLOR_DATA.as_ptr() as *const c_void);
            gl::DrawArrays(gl::TRIANGLES, 0, 3);
        }
        window.swap_buffers();
    }
}