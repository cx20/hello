#![windows_subsystem = "windows"]

extern crate gl;
extern crate glfw;

use gl::types::*;
use glfw::Context;
use std::ffi::CString;
use std::mem;
use std::ptr;
use std::str;

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

// Shader sources
static VS_SRC: &'static str =
   "attribute vec3 position;                     \n\
    attribute vec3 color;                        \n\
    varying   vec4 vColor;                       \n\
    void main() {                                \n\
       vColor = vec4(color, 1.0);                \n\
       gl_Position = vec4(position, 1.0);        \n\
    }";

static FS_SRC: &'static str =
   "precision mediump float;                     \n\
    varying vec4 vColor;                         \n\
    void main() {                                \n\
       gl_FragColor  = vColor;                   \n\
    }";

fn compile_shader(src: &str, ty: GLenum) -> GLuint {
    unsafe {
        let shader = gl::CreateShader(ty);
        let ptr: *const u8 = src.as_bytes().as_ptr();
        let ptr_i8: *const i8 = std::mem::transmute(ptr);
        let len = src.len() as GLint;
        gl::ShaderSource(shader, 1, &ptr_i8, &len);
        gl::CompileShader(shader);
        let mut status = gl::FALSE as GLint;
        gl::GetShaderiv(shader, gl::COMPILE_STATUS, &mut status);

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
        program
    }
}

fn main() {
    unsafe {
        let mut glfw = glfw::init(glfw::FAIL_ON_ERRORS).unwrap();

        glfw.window_hint(glfw::WindowHint::ContextVersion(2, 0));

        let (mut window, _) = glfw.create_window(640, 480, "Hello, World!", glfw::WindowMode::Windowed).expect("Failed");

        window.make_current();

        gl::load_with(|s| window.get_proc_address(s));

        let vs = compile_shader(VS_SRC, gl::VERTEX_SHADER);
        let fs = compile_shader(FS_SRC, gl::FRAGMENT_SHADER);
        let program = link_program(vs, fs);

        let mut vbo : [GLuint;2] = [0, 0];

        gl::GenBuffers(2, &mut vbo[0]);

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[0]);
        gl::BufferData(gl::ARRAY_BUFFER, (VERTEX_DATA.len() * mem::size_of::<GLfloat>()) as GLsizeiptr, mem::transmute(&VERTEX_DATA[0]), gl::STATIC_DRAW);

        gl::EnableVertexAttribArray(0);
        gl::VertexAttribPointer(0, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[1]);
        gl::BufferData(gl::ARRAY_BUFFER, (COLOR_DATA.len() * mem::size_of::<GLfloat>()) as GLsizeiptr, mem::transmute(&COLOR_DATA[0]), gl::STATIC_DRAW);

        gl::EnableVertexAttribArray(1);
        gl::VertexAttribPointer(1, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());

        //gl::BindVertexArray(0);

        gl::UseProgram(program);
        //gl::BindFragDataLocation(program, 0, CString::new("outColor").unwrap().as_ptr());

        while !window.should_close() {
            gl::BindBuffer(gl::ARRAY_BUFFER, vbo[0]);
            gl::VertexAttribPointer(0, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());
            gl::BindBuffer(gl::ARRAY_BUFFER, vbo[1]);
            gl::VertexAttribPointer(1, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());

            glfw.poll_events();

            gl::ClearColor(0.0, 0.0, 0.0, 1.0);
            gl::Clear(gl::COLOR_BUFFER_BIT);

            gl::DrawArrays(gl::TRIANGLES, 0, 3);

            window.swap_buffers();
        }

        gl::DeleteProgram(program);
        gl::DeleteShader(fs);
        gl::DeleteShader(vs);
        gl::DeleteBuffers(1, &vbo[0]);
    }
}