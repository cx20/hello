package main

import (
"runtime"

"github.com/go-gl/gl/v3.3-core/gl"
"github.com/go-gl/glfw/v3.3/glfw"
)

var vertexShader = `
#version 330 core

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
out vec4 vColor;

void main() {
vColor = vec4(color, 1.0);
gl_Position = vec4(position, 1);
}
` + "\x00"

var fragmentShader = `
#version 330 core
precision mediump float;

in vec4 vColor;
out vec4 outColor;

void main() {
outColor = vColor;
}
` + "\x00"

func init() { runtime.LockOSThread() }

func main() {
glfw.Init()
defer glfw.Terminate()

glfw.WindowHint(glfw.Resizable, glfw.False)
glfw.WindowHint(glfw.ContextVersionMajor, 3)
glfw.WindowHint(glfw.ContextVersionMinor, 3)
glfw.WindowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile)
glfw.WindowHint(glfw.OpenGLForwardCompatible, glfw.True)

window, _ := glfw.CreateWindow(640, 480, "Hello, World!", nil, nil)
window.MakeContextCurrent()

gl.Init()

program, _ := newProgram(vertexShader, fragmentShader)
gl.UseProgram(program)

points := []float32{
 0.0,  0.5, 0.0,   1.0, 0.0, 0.0,
 0.5, -0.5, 0.0,   0.0, 1.0, 0.0,
-0.5, -0.5, 0.0,   0.0, 0.0, 1.0,
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

func newProgram(vs, fs string) (uint32, error) {
v, _ := compileShader(vs, gl.VERTEX_SHADER)
f, _ := compileShader(fs, gl.FRAGMENT_SHADER)
p := gl.CreateProgram()
gl.AttachShader(p, v)
gl.AttachShader(p, f)
gl.LinkProgram(p)
return p, nil
}

func compileShader(src string, shaderType uint32) (uint32, error) {
s := gl.CreateShader(shaderType)
csrc := gl.Str(src)
gl.ShaderSource(s, 1, &csrc, nil)
gl.CompileShader(s)
return s, nil
}
