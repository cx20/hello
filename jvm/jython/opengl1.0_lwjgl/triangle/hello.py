from org.lwjgl.glfw import *
from org.lwjgl.opengl import *
from org.lwjgl.glfw.GLFW import *
from org.lwjgl.opengl.GL11 import *

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

        while not glfwWindowShouldClose(self.window):
            glBegin(GL_TRIANGLES)

            glColor3f(1.0, 0.0, 0.0)
            glVertex2f( 0.0,  0.50)
            glColor3f(0.0, 1.0, 0.0)
            glVertex2f( 0.5, -0.50)
            glColor3f(0.0, 0.0, 1.0)
            glVertex2f(-0.5, -0.50)

            glEnd()

            glfwSwapBuffers(self.window);
            glfwPollEvents();

    @staticmethod
    def main():
        hello = Hello()
        hello.run()

if __name__ == '__main__':
    Hello.main()
