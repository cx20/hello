package main

import (
	"runtime"

	"github.com/go-gl/gl/v2.1/gl"
	"github.com/go-gl/glfw/v3.3/glfw"
)

func init() { runtime.LockOSThread() }

func main() {
	glfw.Init()
	defer glfw.Terminate()

	glfw.WindowHint(glfw.ContextVersionMajor, 1)
	glfw.WindowHint(glfw.ContextVersionMinor, 1)

	window, _ := glfw.CreateWindow(640, 480, "Hello, World!", nil, nil)
	window.MakeContextCurrent()

	gl.Init()

	for !window.ShouldClose() {
		gl.Clear(gl.COLOR_BUFFER_BIT)

		colors := []float32{
			1.0, 0.0, 0.0,
			0.0, 1.0, 0.0,
			0.0, 0.0, 1.0,
		}
		vertices := []float32{
			 0.0,  0.5,
			 0.5, -0.5,
			-0.5, -0.5,
		}

		gl.EnableClientState(gl.COLOR_ARRAY)
		gl.EnableClientState(gl.VERTEX_ARRAY)
		gl.ColorPointer(3, gl.FLOAT, 0, gl.Ptr(colors))
		gl.VertexPointer(2, gl.FLOAT, 0, gl.Ptr(vertices))
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 3)

		window.SwapBuffers()
		glfw.PollEvents()
	}
}
