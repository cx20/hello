// forked from https://github.com/kettle11/hello_triangle_wasm_rust

use std::ffi::c_void;

#[no_mangle]
pub extern "C" fn start() {
    unsafe {
        imported::setup_canvas();

        let vertices = [
             0.0, 0.5, 0.0, // v0
            -0.5,-0.5, 0.0, // v1
             0.5,-0.5, 0.0, // v2
        ];

        let colors = [ 
             1.0, 0.0, 0.0, 1.0, // v0
             0.0, 1.0, 0.0, 1.0, // v1
             0.0, 0.0, 1.0, 1.0, // v2
        ];

        let vertex_buffer = imported::create_buffer();
        imported::bind_buffer(GLEnum::ArrayBuffer, vertex_buffer);
        buffer_data_f32(
            GLEnum::ArrayBuffer,
            &vertices,
            GLEnum::StaticDraw,
        );

        let color_buffer = imported::create_buffer();
        imported::bind_buffer(GLEnum::ArrayBuffer, color_buffer);
        buffer_data_f32(
            GLEnum::ArrayBuffer,
            &colors,
            GLEnum::StaticDraw,
        );

        let index_buffer = imported::create_buffer();
        imported::bind_buffer(GLEnum::ElementArrayBuffer, index_buffer);

        buffer_data_u16(GLEnum::ElementArrayBuffer, &[0, 1, 2], GLEnum::StaticDraw);

        let vertex_shader = imported::create_shader(GLEnum::VertexShader);
        shader_source(
            vertex_shader,
            r#"
            attribute vec3 position;
            attribute vec4 color;
            varying   vec4 vColor;
            void main() {
                vColor = color;
                gl_Position = vec4(position, 1.0);
            }
            "#,
        );
        imported::compile_shader(vertex_shader);

        // Create the fragment shader
        let fragment_shader = imported::create_shader(GLEnum::FragmentShader);
        shader_source(
            fragment_shader,
            r#"
            precision mediump float;
            varying   vec4 vColor;
            void main() {
                gl_FragColor = vColor;
            }
            "#,
        );
        imported::compile_shader(fragment_shader);

        let shader_program = imported::create_program();
        imported::attach_shader(shader_program, vertex_shader);
        imported::attach_shader(shader_program, fragment_shader);
        imported::link_program(shader_program);
        imported::use_program(shader_program);

        let attrib_location0 = get_attrib_location(shader_program, "position").unwrap();
        imported::enable_vertex_attrib_array(attrib_location0);
        imported::bind_buffer(GLEnum::ArrayBuffer, vertex_buffer);
        imported::vertex_attrib_pointer(attrib_location0 as u32, 3, GLEnum::Float, false, 0, 0);

        let attrib_location1 = get_attrib_location(shader_program, "color").unwrap();
        imported::enable_vertex_attrib_array(attrib_location1);
        imported::bind_buffer(GLEnum::ArrayBuffer, color_buffer);
        imported::vertex_attrib_pointer(attrib_location1 as u32, 4, GLEnum::Float, false, 0, 0);

        imported::bind_buffer(GLEnum::ElementArrayBuffer, index_buffer);
        imported::clear_color(1.0, 1.0, 1.0, 1.0);
        imported::clear(GLEnum::ColorBufferBit);
        imported::draw_elements(GLEnum::Triangles, 3, GLEnum::UnsignedShort, 0);
    }
}

pub fn shader_source(shader: JSObject, source: &str) {
    unsafe { imported::shader_source(shader, source as *const str as *const c_void, source.len()) }
}

pub fn get_attrib_location(program: JSObject, name: &str) -> Option<GLUint> {
    unsafe {
        let result =
            imported::get_attrib_location(program, name as *const str as *const c_void, name.len());
        if result == -1 {
            None
        } else {
            Some(result as u32)
        }
    }
}

pub fn bind_buffer(target: GLEnum, gl_object: Option<JSObject>) {
    unsafe { imported::bind_buffer(target, gl_object.unwrap_or(JSObject::null())) }
}

pub fn buffer_data_f32(target: GLEnum, data: &[f32], usage: GLEnum) {
    unsafe {
        imported::buffer_data_f32(
            target,
            data as *const [f32] as *const c_void,
            data.len(),
            usage,
        )
    }
}

pub fn buffer_data_u16(target: GLEnum, data: &[u16], usage: GLEnum) {
    unsafe {
        imported::buffer_data_u16(
            target,
            data as *const [u16] as *const c_void,
            data.len(),
            usage,
        )
    }
}

mod imported {
    use super::*;

    extern "C" {
        pub fn setup_canvas();
        pub fn create_buffer() -> JSObject;
        pub fn bind_buffer(target: GLEnum, gl_object: JSObject);
        pub fn buffer_data_f32(
            target: GLEnum,
            data: *const c_void,
            data_length: usize,
            usage: GLEnum,
        );

        pub fn buffer_data_u16(
            target: GLEnum,
            data: *const c_void,
            data_length: usize,
            usage: GLEnum,
        );

        pub fn create_shader(shader_type: GLEnum) -> JSObject;
        pub fn shader_source(shader: JSObject, source: *const c_void, source_length: usize);
        pub fn compile_shader(shader: JSObject);
        pub fn create_program() -> JSObject;
        pub fn attach_shader(program: JSObject, shader: JSObject);
        pub fn link_program(program: JSObject);
        pub fn use_program(program: JSObject);
        pub fn get_attrib_location(
            program: JSObject,
            name: *const c_void,
            name_length: usize,
        ) -> GLint;
        pub fn vertex_attrib_pointer(
            index: GLUint,
            size: GLint,
            _type: GLEnum,
            normalized: bool,
            stride: GLsizei,
            pointer: GLintptr,
        );
        pub fn enable_vertex_attrib_array(index: GLUint);
        pub fn clear_color(r: f32, g: f32, b: f32, a: f32);
        pub fn clear(mask: GLEnum);
        pub fn draw_elements(mode: GLEnum, count: GLsizei, _type: GLEnum, offset: GLintptr);
    }
}

#[derive(Clone, Copy)]
#[repr(C)]
pub struct JSObject(u32);

impl JSObject {
    pub const fn null() -> Self {
        JSObject(0)
    }
}

// Sourced from here: https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Constants
#[repr(u32)]
pub enum GLEnum {
    Triangles          = 0x0004,
    ArrayBuffer        = 0x8892,
    ElementArrayBuffer = 0x8893,
    VertexShader       = 0x8B31,
    FragmentShader     = 0x8B30,
    Byte               = 0x1400,
    UnsignedByte       = 0x1401,
    Short              = 0x1402,
    UnsignedShort      = 0x1403,
    Int                = 0x1404,
    UnsignedInt        = 0x1405,
    Float              = 0x1406,
    StaticDraw         = 0x88E4,
    DynamicDraw        = 0x88E8,
    ColorBufferBit     = 0x00004000,
}

pub type GLUint   = u32;
pub type GLint    = i32;
pub type GLsizei  = i32;
pub type GLintptr = i32;
