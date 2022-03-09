#![windows_subsystem = "windows"]

use std::{
    ffi::{CString},
    mem, ptr,
};

//use anyhow::Result;
use gl::types::{GLboolean, GLenum, GLfloat, GLint, GLsizeiptr, GLuint};
use sdl2::{event::Event};


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
        let sdl = sdl2::init().unwrap();
        let video_subsystem = sdl.video().unwrap();

        let window = video_subsystem
            .window("Hello, World!", 640, 480)
            .opengl()
            .resizable()
            .build()
            .unwrap();
        
    
        let _gl_context = window.gl_create_context().unwrap();
        let _gl =
            gl::load_with(|s| video_subsystem.gl_get_proc_address(s) as *const std::os::raw::c_void);

        let vs = compile_shader(VS_SRC, gl::VERTEX_SHADER);
        let fs = compile_shader(FS_SRC, gl::FRAGMENT_SHADER);
        let program = link_program(vs, fs);

        let pos_attr = gl::GetAttribLocation(program, CString::new("position").unwrap().as_ptr());
        let col_attr = gl::GetAttribLocation(program, CString::new("color").unwrap().as_ptr());

        let mut vbo : [GLuint;2] = [0, 0];

        gl::GenBuffers(2, &mut vbo[0]);

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[0]);
        gl::BufferData(gl::ARRAY_BUFFER, (VERTEX_DATA.len() * mem::size_of::<GLfloat>()) as GLsizeiptr, mem::transmute(&VERTEX_DATA[0]), gl::STATIC_DRAW);

        gl::EnableVertexAttribArray(pos_attr as GLuint);
        gl::VertexAttribPointer(pos_attr as GLuint, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());

        gl::BindBuffer(gl::ARRAY_BUFFER, vbo[1]);
        gl::BufferData(gl::ARRAY_BUFFER, (COLOR_DATA.len() * mem::size_of::<GLfloat>()) as GLsizeiptr, mem::transmute(&COLOR_DATA[0]), gl::STATIC_DRAW);

        gl::EnableVertexAttribArray(col_attr as GLuint);
        gl::VertexAttribPointer(col_attr as GLuint, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());

        gl::UseProgram(program);

        let mut event_pump = sdl.event_pump().unwrap();
        'mainloop: loop {
            loop {
                match event_pump.poll_event() {
                    None => break,
                    Some(Event::Quit { .. }) => break 'mainloop,
                    _ => (),
                }
            }

            // Clear the screen to black
            gl::ClearColor(0.0, 0.0, 0.0, 1.0);
            gl::Clear(gl::COLOR_BUFFER_BIT);

            gl::BindBuffer(gl::ARRAY_BUFFER, vbo[0]);
            gl::VertexAttribPointer(pos_attr as GLuint, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());
            gl::BindBuffer(gl::ARRAY_BUFFER, vbo[1]);
            gl::VertexAttribPointer(col_attr as GLuint, 3, gl::FLOAT, gl::FALSE as GLboolean, 0, ptr::null());

            // Draw a triangle from the 3 vertices
            gl::DrawArrays(gl::TRIANGLES, 0, 3);

            window.gl_swap_window();
        }
    }
}