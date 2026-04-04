extern crate gl;
extern crate glfw;

use glfw::Context;

#[link(name = "GL")]
extern "C" {
    fn glBegin(mode: u32);
    fn glEnd();
    fn glColor3f(r: f32, g: f32, b: f32);
    fn glVertex2f(x: f32, y: f32);
}

const GL_TRIANGLES: u32 = 0x0004;

fn main() {
    let mut glfw = glfw::init(glfw::fail_on_errors).unwrap();
    glfw.window_hint(glfw::WindowHint::ContextVersion(1, 0));
    let (mut window, _) = glfw
        .create_window(640, 480, "Hello, World!", glfw::WindowMode::Windowed)
        .expect("Failed to create GLFW window");
    window.make_current();
    gl::load_with(|s| window.get_proc_address(s) as *const _);

    while !window.should_close() {
        glfw.poll_events();
        unsafe {
            glBegin(GL_TRIANGLES);
            glColor3f(1.0, 0.0, 0.0); glVertex2f( 0.0,  0.5);
            glColor3f(0.0, 1.0, 0.0); glVertex2f( 0.5, -0.5);
            glColor3f(0.0, 0.0, 1.0); glVertex2f(-0.5, -0.5);
            glEnd();
        }
        window.swap_buffers();
    }
}