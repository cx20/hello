#![windows_subsystem = "windows"]

extern crate gl;
extern crate glfw;

use windows::Win32::Graphics::OpenGL::*;
use glfw::Context;

fn main() {
    unsafe {
        let mut glfw = glfw::init(glfw::fail_on_errors).unwrap();
        glfw.window_hint(glfw::WindowHint::ContextVersion(1, 0));
        let (mut window, _) = glfw.create_window(640, 480, "Hello, World!", glfw::WindowMode::Windowed).expect("Failed");
        window.make_current();
        gl::load_with(|s| window.get_proc_address(s));

        while !window.should_close() {
            glfw.poll_events();

            glBegin(GL_TRIANGLES);

                glColor3f(1.0, 0.0, 0.0);   glVertex2f( 0.0,  0.50);
                glColor3f(0.0, 1.0, 0.0);   glVertex2f( 0.5, -0.50);
                glColor3f(0.0, 0.0, 1.0);   glVertex2f(-0.5, -0.50);

            glEnd();

            window.swap_buffers();
        }
    }
}