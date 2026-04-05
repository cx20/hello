import Foundation
import GLFW

func main() {
    guard glfwInit() != 0 else {
        fputs("Failed to initialize GLFW\n", stderr)
        exit(1)
    }
    defer { glfwTerminate() }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1)

    guard let window = glfwCreateWindow(640, 480, "Hello, OpenGL 1.1 World!", nil, nil) else {
        fputs("Failed to create GLFW window\n", stderr)
        exit(1)
    }
    defer { glfwDestroyWindow(window) }

    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)

    let vertices: [GLfloat] = [
         0.0,  0.7,
        -0.7, -0.7,
         0.7, -0.7
    ]
    let colors: [GLfloat] = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    ]

    while glfwWindowShouldClose(window) == 0 {
        var width: Int32 = 0
        var height: Int32 = 0
        glfwGetFramebufferSize(window, &width, &height)
        glViewport(0, 0, width, height)

        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glEnableClientState(GLenum(GL_VERTEX_ARRAY))
        glEnableClientState(GLenum(GL_COLOR_ARRAY))

        vertices.withUnsafeBytes { ptr in
            glVertexPointer(2, GLenum(GL_FLOAT), 0, ptr.baseAddress)
        }
        colors.withUnsafeBytes { ptr in
            glColorPointer(3, GLenum(GL_FLOAT), 0, ptr.baseAddress)
        }

        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)

        glDisableClientState(GLenum(GL_COLOR_ARRAY))
        glDisableClientState(GLenum(GL_VERTEX_ARRAY))

        glfwSwapBuffers(window)
        glfwPollEvents()
    }
}

main()
