package main

import (
	"runtime"

	"github.com/go-gl/gl/v2.1/gl"
	"github.com/go-gl/glfw/v3.3/glfw"
)

var vertexShader = `
attribute vec3 position;
attribute vec3 color;
varying   vec4 vColor;

void main() {
	vColor = vec4(color, 1.0);
	gl_Position = vec4(position, 1.0);
}
` + "\x00"

var fragmentShader = `
varying vec4 vColor;

void main() {
	gl_FragColor = vColor;
}
` + "\x00"

func init() { runtime.LockOSThread() }

func main() {
	glfw.Init()
	defer glfw.Terminate()

	glfw.WindowHint(glfw.ContextVersionMajor, 2)
	glfw.WindowHint(glfw.ContextVersionMinor, 0)

	window, _ := glfw.CreateWindow(640, 480, "Hello, World!", nil, nil)
	window.MakeContextCurrent()

	gl.Init()

	program, _ := newProgram(vertexShader, fragmentShader)
	gl.UseProgram(program)

	vertices := []float32{
		 0.0,  0.5, 0.0,
		 0.5, -0.5, 0.0,
		-0.5, -0.5, 0.0,
	}
	colors := []float32{
		1.0, 0.0, 0.0,
		0.0, 1.0, 0.0,
		0.0, 0.0, 1.0,
	}

	var vbo [2]uint32
	gl.GenBuffers(2, &vbo[0])

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo[0])
	gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*4, gl.Ptr(vertices), gl.STATIC_DRAW)

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo[1])
	gl.BufferData(gl.ARRAY_BUFFER, len(colors)*4, gl.Ptr(colors), gl.STATIC_DRAW)

	posAttrib := uint32(gl.GetAttribLocation(program, gl.Str("position\x00")))
	gl.EnableVertexAttribArray(posAttrib)

	colAttrib := uint32(gl.GetAttribLocation(program, gl.Str("color\x00")))
	gl.EnableVertexAttribArray(colAttrib)

	for !window.ShouldClose() {
		gl.Clear(gl.COLOR_BUFFER_BIT)

		gl.BindBuffer(gl.ARRAY_BUFFER, vbo[0])
		gl.VertexAttribPointer(posAttrib, 3, gl.FLOAT, false, 0, gl.PtrOffset(0))

		gl.BindBuffer(gl.ARRAY_BUFFER, vbo[1])
		gl.VertexAttribPointer(colAttrib, 3, gl.FLOAT, false, 0, gl.PtrOffset(0))

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
