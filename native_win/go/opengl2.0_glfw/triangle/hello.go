package main

import (
    "github.com/go-gl/gl/v3.3-core/gl"
    "github.com/go-gl/glfw/v3.3/glfw"
)

var vertexShader = `
attribute vec3 position;
attribute vec3 color;
varying   vec4 vColor;

void main() {
    vColor = vec4(color, 1.0);
    gl_Position = vec4(position, 1);
}
` + "\x00"

var fragmentShader = `
precision mediump float;

varying vec4 vColor;

void main() {
    gl_FragColor = vColor;
}
` + "\x00"

func main() {
    glfw.Init()

    window, _ := glfw.CreateWindow(640, 480, "Hello, World!", nil, nil)
    window.MakeContextCurrent()

    gl.Init()

    program, _ := newProgram(vertexShader, fragmentShader)
    gl.UseProgram(program)

    points := []float32{
         0.0,  0.5, 0.0,   1.0,  0.0,  0.0,
         0.5, -0.5, 0.0,   0.0,  1.0,  0.0,
        -0.5, -0.5, 0.0,   0.0,  0.0,  1.0,
    }

    var vao uint32
    gl.GenVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    defer gl.BindVertexArray(0)

    var vbo uint32
    gl.GenBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(points)*4, gl.Ptr(points), gl.STATIC_DRAW)

    vertAttrib := uint32(gl.GetAttribLocation(program, gl.Str("position\x00")))
    gl.EnableVertexAttribArray(vertAttrib)
    gl.VertexAttribPointer(vertAttrib, 3, gl.FLOAT, false, 6*4, gl.PtrOffset(0))

    colAttrib := uint32(gl.GetAttribLocation(program, gl.Str("color\x00")))
    gl.EnableVertexAttribArray(colAttrib)
    gl.VertexAttribPointer(colAttrib, 3, gl.FLOAT, false, 6*4, gl.PtrOffset(3*4))

    for !window.ShouldClose() {
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        gl.UseProgram(program)

        gl.BindVertexArray(vao)

        gl.DrawArrays(gl.TRIANGLES, 0, 3)

        window.SwapBuffers()
        glfw.PollEvents()
    }
}

func newProgram(vertexShaderSource, fragmentShaderSource string) (uint32, error) {
    vertexShader, _ := compileShader(vertexShaderSource, gl.VERTEX_SHADER)
    fragmentShader, _ := compileShader(fragmentShaderSource, gl.FRAGMENT_SHADER)
    
    program := gl.CreateProgram()

    gl.AttachShader(program, vertexShader)
    gl.AttachShader(program, fragmentShader)
    gl.LinkProgram(program)

    return program, nil
}

func compileShader(source string, shaderType uint32) (uint32, error) {
    shader := gl.CreateShader(shaderType)

    csource := gl.Str(source)
    gl.ShaderSource(shader, 1, &csource, nil)
    gl.CompileShader(shader)

    var status int32
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &status)

    return shader, nil
}