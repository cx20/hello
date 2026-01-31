from OpenGL.GL import *
import glfw

def main():
    glfw.init()

    window = glfw.create_window(640, 480, 'Hello, World', None, None)
    glfw.make_context_current(window)

    while not glfw.window_should_close(window):
        glBegin(GL_TRIANGLES)

        glColor3f(1.0, 0.0, 0.0)
        glVertex2f( 0.0,  0.50)
        glColor3f(0.0, 1.0, 0.0)
        glVertex2f( 0.5, -0.50)
        glColor3f(0.0, 0.0, 1.0)
        glVertex2f(-0.5, -0.50)

        glEnd()

        glfw.swap_buffers(window)
        glfw.poll_events()

    glfw.destroy_window(window)
    glfw.terminate()

if __name__ == "__main__":
    main()
