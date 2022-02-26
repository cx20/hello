package main

import (
    "github.com/go-gl/gl/v2.1/gl"
    "github.com/go-gl/glfw/v3.3/glfw"
)

func main() {
    glfw.Init();

    window, _ := glfw.CreateWindow(640, 480, "Hello, World!", nil, nil)
    window.MakeContextCurrent()

    gl.Init()

    for !window.ShouldClose() {
        drawTriangle()
        window.SwapBuffers()
        glfw.PollEvents()
    }
}

func drawTriangle() {
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

    gl.EnableClientState(gl.COLOR_ARRAY)
    gl.EnableClientState(gl.VERTEX_ARRAY)

    colors := []float32{
         1.0,  0.0,  0.0,
         0.0,  1.0,  0.0,
         0.0,  0.0,  1.0,
    }
    vertices := []float32{
         0.0,  0.5,
         0.5, -0.5,
        -0.5, -0.5,
    }

    gl.ColorPointer(3, gl.FLOAT, 0,  gl.Ptr(colors))
    gl.VertexPointer(2, gl.FLOAT, 0,  gl.Ptr(vertices))

    gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 3)
}
