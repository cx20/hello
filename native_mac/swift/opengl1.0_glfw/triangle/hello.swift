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

    guard let window = glfwCreateWindow(640, 480, "Hello, OpenGL 1.0 World!", nil, nil) else {
        fputs("Failed to create GLFW window\n", stderr)
        exit(1)
    }
    defer { glfwDestroyWindow(window) }

    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)

    while glfwWindowShouldClose(window) == 0 {
        var width: Int32 = 0
        var height: Int32 = 0
        glfwGetFramebufferSize(window, &width, &height)
        glViewport(0, 0, width, height)

        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glBegin(GLenum(GL_TRIANGLES))
        glColor3f(1.0, 0.0, 0.0); glVertex2f( 0.0,  0.7)
        glColor3f(0.0, 1.0, 0.0); glVertex2f(-0.7, -0.7)
        glColor3f(0.0, 0.0, 1.0); glVertex2f( 0.7, -0.7)
        glEnd()

        glfwSwapBuffers(window)
        glfwPollEvents()
    }
}

main()
