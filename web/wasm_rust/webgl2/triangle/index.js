let gl;
let canvas;

function setup_canvas() {
    c = document.getElementById("c");
    gl = c.getContext("webgl2");
    resizeCanvas();
    window.addEventListener("resize", function(){
        resizeCanvas();
    });
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    const vertex_buffer = gl.createBuffer();
    gl.bindBuffer(0x8892, vertex_buffer);
}

function resizeCanvas() {
    c.width = window.innerWidth;
    c.height = window.innerHeight;
    gl.viewport(0, 0, c.width, c.height);
}

const decoder = new TextDecoder();

let wasm_memory;

let js_objects = [null];

let importObject = {
    env: {
        setup_canvas: setup_canvas,
        create_buffer: function () {
            return js_objects.push(gl.createBuffer()) - 1;
        },
        bind_buffer: function (gl_enum, id) {
            gl.bindBuffer(gl_enum, js_objects[id]);
        },
        buffer_data_f32: function (target, pointer, length, usage) {
            const data = new Float32Array(wasm_memory.buffer, pointer, length);
            gl.bufferData(target, data, usage);
        },
        buffer_data_u16: function (target, pointer, length, usage) {
            const data = new Uint16Array(wasm_memory.buffer, pointer, length);
            gl.bufferData(target, data, usage);
        },
        create_shader: function (gl_enum) {
            return js_objects.push(gl.createShader(gl_enum)) - 1;
        },
        compile_shader: function (shader) {
            gl.compileShader(js_objects[shader]);
        },
        shader_source: function (shader, pointer, length) {
            const string_data = new Uint8Array(wasm_memory.buffer, pointer, length);
            const shader_string = decoder.decode(string_data);
            gl.shaderSource(js_objects[shader], shader_string);
        },
        create_program: function () {
            return js_objects.push(gl.createProgram()) - 1;
        },
        attach_shader: function (program, shader) {
            gl.attachShader(js_objects[program], js_objects[shader]);
        },
        link_program: function (program) {
            gl.linkProgram(js_objects[program]);
        },
        use_program: function (program) {
            gl.useProgram(js_objects[program]);
        },
        get_attrib_location: function (program, pointer, length) {
            const string_data = new Uint8Array(wasm_memory.buffer, pointer, length);
            const string = decoder.decode(string_data);
            return gl.getAttribLocation(js_objects[program], string);
        },
        vertex_attrib_pointer: function (index, size, type, normalized, stride, offset) {
            gl.vertexAttribPointer(index, size, type, normalized, stride, offset);
        },
        enable_vertex_attrib_array: function (index) {
            gl.enableVertexAttribArray(index)
        },
        clear_color: function (r, g, b, a) {
            gl.clearColor(r, g, b, a);
        },
        clear: function (gl_enum) {
            gl.clear(gl_enum);
        },
        draw_elements: function (mode, count, type, offset) {
            gl.drawElements(mode, count, type, offset);
        },
    }
};

fetch('hello.wasm').then(response =>
    response.arrayBuffer()
).then(bytes =>
    WebAssembly.instantiate(bytes, importObject)
).then(results => {
    wasm_memory = results.instance.exports.memory;

    results.instance.exports.start();
});
