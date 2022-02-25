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

    gl.Begin(gl.TRIANGLES)

    gl.Color3f(1.0, 0.0, 0.0); gl.Vertex2f( 0.0,  0.5)
    gl.Color3f(0.0, 1.0, 0.0); gl.Vertex2f( 0.5, -0.5)
    gl.Color3f(0.0, 0.0, 1.0); gl.Vertex2f(-0.5, -0.5)

    gl.End()
}
