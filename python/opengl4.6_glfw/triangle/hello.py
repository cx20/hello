from OpenGL.GL import *
import glfw
import numpy as np

vertexShaderSource = r'''
#version 460 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
out vec4 vColor;
void main()
{
    vColor = color;
    gl_Position = vec4(position, 1.0);
}
'''

fragmentShaderSource = r'''
#version 460 core
in  vec4 vColor;
out vec4 outColor;
void main()
{
    outColor = vColor;
}
'''

class Shader:
    def __init__(self):
        self.handle = glCreateProgram()

    def attach_shader(self, content, type):
        shader = glCreateShader(type)
        glShaderSource(shader, [content])
        glCompileShader(shader)

        status = ctypes.c_uint(GL_UNSIGNED_INT)
        glGetShaderiv(shader, GL_COMPILE_STATUS, status)
        glAttachShader(self.handle, shader)
        glDeleteShader(shader)

    def link(self):
        glLinkProgram(self.handle)
        status = ctypes.c_uint(GL_UNSIGNED_INT)
        glGetProgramiv(self.handle, GL_LINK_STATUS, status)

    def use(self):
        glUseProgram(self.handle)

    def unuse(self):
        glUseProgram(0)

def main():
    glfw.init()

    window = glfw.create_window(640, 480, "Hello, World!", None, None)

    glfw.window_hint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.window_hint(glfw.CONTEXT_VERSION_MINOR, 6)
    glfw.make_context_current(window)

    vertices =  np.array([
        [ 0.0, 0.5, 0.0],
        [ 0.5,-0.5, 0.0],
        [-0.5,-0.5, 0.0]
    ], dtype=np.float32)

    colors =  np.array([
        [ 1.0, 0.0, 0.0, 1.0],
        [ 0.0, 1.0, 0.0, 1.0],
        [-0.0, 0.0, 1.0, 1.0]
    ], dtype=np.float32)

    vao = glGenVertexArrays(1)
    glBindVertexArray(vao)

    vbo = glGenBuffers(2)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glEnableVertexAttribArray(0)
    glBufferData(GL_ARRAY_BUFFER, vertices.nbytes, vertices, GL_STATIC_DRAW)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, None)

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glEnableVertexAttribArray(1)
    glBufferData(GL_ARRAY_BUFFER, colors.nbytes, colors, GL_STATIC_DRAW)
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 0, None)

    glBindVertexArray(0)

    program = Shader()
    program.attach_shader(vertexShaderSource, GL_VERTEX_SHADER)
    program.attach_shader(fragmentShaderSource, GL_FRAGMENT_SHADER)
    program.link()

    glClearColor(0, 0, 0, 1)
    while glfw.window_should_close(window) == glfw.FALSE:
        glClear(GL_COLOR_BUFFER_BIT)

        program.use()

        glBindVertexArray(vao)
        glDrawArrays(GL_TRIANGLES, 0, 3)
        glBindVertexArray(0)

        program.unuse()

        glfw.swap_buffers(window)
        glfw.wait_events()

    glDeleteProgram(program.handle)
    glDeleteVertexArrays(1, [vao])
    glDeleteBuffers(2, vbo)

if __name__ == "__main__":
    main()
