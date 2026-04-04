extern crate gl;
extern crate glfw;

use std::ffi::CString;
use std::ptr;
use glfw::Context;

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

const VERT_SRC: &str = "#version 110
attribute vec3 position;
attribute vec3 color;
varying   vec4 vColor;
void main() {
  vColor = vec4(color, 1.0);
  gl_Position = vec4(position, 1.0);
}";

const FRAG_SRC: &str = "#version 110
varying vec4 vColor;
void main() {
  gl_FragColor = vColor;
}";

fn main() {
    let mut glfw = glfw::init(glfw::fail_on_errors).unwrap();
    glfw.window_hint(glfw::WindowHint::ContextVersion(2, 0));
    let (mut window, _) = glfw
        .create_window(640, 480, "Hello, World!", glfw::WindowMode::Windowed)
        .expect("Failed to create GLFW window");
    window.make_current();
    gl::load_with(|s| window.get_proc_address(s) as *const _);

    unsafe {
        let vert = compile_shader(VERT_SRC, gl::VERTEX_SHADER);
        let frag = compile_shader(FRAG_SRC, gl::FRAGMENT_SHADER);
        let program = link_program(vert, frag);
        gl::UseProgram(program);

        let pos_name = CString::new("position").unwrap();
        let col_name = CString::new("color").unwrap();
        let pos_attrib = gl::GetAttribLocation(program, pos_name.as_ptr());
        let col_attrib = gl::GetAttribLocation(program, col_name.as_ptr());

        let vertices: [f32; 9] = [0.0, 0.5, 0.0,  0.5, -0.5, 0.0,  -0.5, -0.5, 0.0];
        let colors:   [f32; 9] = [1.0, 0.0, 0.0,  0.0,  1.0, 0.0,   0.0,  0.0, 1.0];

        let mut vbo = [0u32; 2];
        gl::GenBuffers(2, vbo.as_mut_ptr());

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[0]);
        gl::BufferData(gl::ARRAY_BUFFER,
            (vertices.len() * std::mem::size_of::<f32>()) as isize,
            vertices.as_ptr() as *const _, gl::STATIC_DRAW);
        gl::EnableVertexAttribArray(pos_attrib as u32);

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[1]);
        gl::BufferData(gl::ARRAY_BUFFER,
            (colors.len() * std::mem::size_of::<f32>()) as isize,
            colors.as_ptr() as *const _, gl::STATIC_DRAW);
        gl::EnableVertexAttribArray(col_attrib as u32);

        gl::ClearColor(0.0, 0.0, 0.0, 1.0);

        while !window.should_close() {
            glfw.poll_events();

            gl::BindBuffer(gl::ARRAY_BUFFER, vbo[0]);
            gl::VertexAttribPointer(pos_attrib as u32, 3, gl::FLOAT, gl::FALSE, 0, ptr::null());
            gl::BindBuffer(gl::ARRAY_BUFFER, vbo[1]);
            gl::VertexAttribPointer(col_attrib as u32, 3, gl::FLOAT, gl::FALSE, 0, ptr::null());

            gl::Clear(gl::COLOR_BUFFER_BIT);
            gl::DrawArrays(gl::TRIANGLES, 0, 3);

            window.swap_buffers();
        }

        gl::DeleteBuffers(2, vbo.as_ptr());
        gl::DeleteProgram(program);
        gl::DeleteShader(vert);
        gl::DeleteShader(frag);
    }
}