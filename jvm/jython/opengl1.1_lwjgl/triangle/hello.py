from org.lwjgl.glfw import *
from org.lwjgl.opengl import *
from org.lwjgl.glfw.GLFW import *
from org.lwjgl.opengl.GL11 import *
import jarray
from java.nio import ByteBuffer
from java.nio import ByteOrder

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
        glfwSwapInterval(1)
        glfwShowWindow(self.window)

    def loop(self):
        GL.createCapabilities()
        
        glClearColor(1.0, 0.0, 0.0, 1.0)

        while not glfwWindowShouldClose(self.window):
            glEnableClientState(GL_COLOR_ARRAY)
            glEnableClientState(GL_VERTEX_ARRAY)
            
            colors = jarray.array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], 'f')
            vertices = jarray.array([0.0, 0.5, 0.5, -0.5, -0.5, -0.5], 'f')

            vertexColorBuffer = ByteBuffer.allocateDirect(4 * len(colors)).order(ByteOrder.nativeOrder()).asFloatBuffer()
            vertexColorBuffer.put(colors)
            vertexColorBuffer.position(0)

            vertexBuffer = ByteBuffer.allocateDirect(4 * len(vertices)).order(ByteOrder.nativeOrder()).asFloatBuffer()
            vertexBuffer.put(vertices)
            vertexBuffer.position(0)
                        
            glColorPointer(3, GL_FLOAT, 0, vertexColorBuffer)
            glVertexPointer(2, GL_FLOAT, 0, vertexBuffer)
            
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
            
            glfwSwapBuffers(self.window);
            glfwPollEvents();

    @staticmethod
    def main():
        hello = Hello()
        hello.run()

if __name__ == '__main__':
    Hello.main()
