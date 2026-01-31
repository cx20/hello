from OpenGL.GL import *
import glfw
import numpy as np

vertexShaderSource = r'''#version 300 es
in  vec3 position;
in  vec3 color;
out vec4 vColor;
void main()
{
    vColor = vec4(color, 1.0);
    gl_Position = vec4(position, 1.0);
}
'''

fragmentShaderSource = r'''#version 300 es
precision mediump float;
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

    glfw.window_hint( glfw.CLIENT_API, glfw.OPENGL_ES_API);
    glfw.window_hint( glfw.CONTEXT_VERSION_MAJOR, 3 );
    glfw.window_hint( glfw.CONTEXT_VERSION_MINOR, 0 );
    glfw.window_hint( glfw.OPENGL_FORWARD_COMPAT, GL_TRUE );
    glfw.window_hint( glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE );

    glfw.make_context_current(window)

    program = Shader()
    program.attach_shader(vertexShaderSource, GL_VERTEX_SHADER)
    program.attach_shader(fragmentShaderSource, GL_FRAGMENT_SHADER)
    program.link()

    vertices =  np.array([
        [ 0.0, 0.5, 0.0],
        [ 0.5,-0.5, 0.0],
        [-0.5,-0.5, 0.0]
    ], dtype=np.float32)

    colors =  np.array([
        [ 1.0, 0.0, 0.0],
        [ 0.0, 1.0, 0.0],
        [-0.0, 0.0, 1.0]
    ], dtype=np.float32)

    posAttrib = glGetAttribLocation(program.handle, "position")
    glEnableVertexAttribArray(posAttrib)

    colAttrib = glGetAttribLocation(program.handle, "color")
    glEnableVertexAttribArray(colAttrib)

    vbo = glGenBuffers(2)
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
    glBufferData(GL_ARRAY_BUFFER, vertices.nbytes, vertices, GL_STATIC_DRAW)
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, None)

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    glBufferData(GL_ARRAY_BUFFER, colors.nbytes, colors, GL_STATIC_DRAW)
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, None)

    glClearColor(0, 0, 0, 1)
    while glfw.window_should_close(window) == glfw.FALSE:
        glClear(GL_COLOR_BUFFER_BIT)

        program.use()

        glBindBuffer(GL_ARRAY_BUFFER, vbo[0])
        glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, None)

        glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
        glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, None)

        glDrawArrays(GL_TRIANGLES, 0, 3)
        glBindVertexArray(0)

        program.unuse()

        glfw.swap_buffers(window)
        glfw.wait_events()

    glDeleteProgram(program.handle)
    #glDeleteVertexArrays(1, [vao])
    glDeleteBuffers(2, vbo)

if __name__ == "__main__":
    main()
