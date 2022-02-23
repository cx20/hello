from org.lwjgl.glfw import *
from org.lwjgl.opengl import *
from org.lwjgl.glfw.GLFW import *
from org.lwjgl.opengl.GL33 import *
import jarray

vertexShaderSource = r'''
#version 330 core
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
#version 330 core
in  vec4 vColor;
out vec4 outColor;
void main()
{
    outColor = vColor;
}
'''

class  Hello:
    def __init__(self):
        self.window = 0

    def run(self):
        self.init()
        self.loop()
        
        glfwDestroyWindow(self.window)
        glfwTerminate()

    def init(self):
        glfwInit()
        
        glfwDefaultWindowHints()
        glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE)
        glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE)
        
        self.window = glfwCreateWindow(640, 480, "Hello, World!", 0, 0)
        
        glfwMakeContextCurrent(self.window)

        self.initShader()
        self.initBuffer()

        glfwSwapInterval(1)
        glfwShowWindow(self.window)

    def initShader(self):
        GL.createCapabilities()

        vs = glCreateShader(GL_VERTEX_SHADER)
        fs = glCreateShader(GL_FRAGMENT_SHADER)

        glShaderSource(vs, vertexShaderSource)
        glCompileShader(vs)

        glShaderSource(fs, fragmentShaderSource)
        glCompileShader(fs)

        self.program = glCreateProgram()
        glAttachShader(self.program, vs)
        glAttachShader(self.program, fs)
        glLinkProgram(self.program)
        glUseProgram(self.program) 

        self.posAttrib = glGetAttribLocation(self.program, "position")
        glEnableVertexAttribArray(self.posAttrib)

        self.colAttrib = glGetAttribLocation(self.program, "color")
        glEnableVertexAttribArray(self.colAttrib)

    def initBuffer(self):
        colors = jarray.array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], 'f')
        vertices = jarray.array([0.0, 0.5, 0.0, 0.5, -0.5, 0.0, -0.5, -0.5, 0.0], 'f')

        self.vbo0 = glGenBuffers()
        self.vbo1 = glGenBuffers()

        glBindBuffer(GL_ARRAY_BUFFER, self.vbo0)
        glBufferData(GL_ARRAY_BUFFER, vertices, GL_STATIC_DRAW)
        glVertexAttribPointer(self.posAttrib, 3, GL_FLOAT, False, 0, 0)

        glBindBuffer(GL_ARRAY_BUFFER, self.vbo1)
        glBufferData(GL_ARRAY_BUFFER, colors, GL_STATIC_DRAW)
        glVertexAttribPointer(self.colAttrib, 3, GL_FLOAT, False, 0, 0)

    def loop(self):
        GL.createCapabilities()
        
        glClearColor(0.0, 0.0, 0.0, 1.0)

        while not glfwWindowShouldClose(self.window):
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

            glBindBuffer(GL_ARRAY_BUFFER, self.vbo0)
            glVertexAttribPointer(self.posAttrib, 3, GL_FLOAT, False, 0, 0)

            glBindBuffer(GL_ARRAY_BUFFER, self.vbo1)
            glVertexAttribPointer(self.colAttrib, 3, GL_FLOAT, False, 0, 0)
            
            glDrawArrays(GL_TRIANGLES, 0, 3)
            
            glfwSwapBuffers(self.window)
            glfwPollEvents()

    @staticmethod
    def main():
        hello = Hello()
        hello.run()

if __name__ == '__main__':
    Hello.main()
