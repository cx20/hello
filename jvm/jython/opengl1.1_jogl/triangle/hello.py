from java.lang import System
from javax.swing import JFrame
from com.jogamp.opengl import GL2
from com.jogamp.opengl import GLAutoDrawable
from com.jogamp.opengl import GLCapabilities
from com.jogamp.opengl import GLEventListener
from com.jogamp.opengl import GLProfile
from com.jogamp.opengl.awt import GLCanvas

from com.jogamp.common.nio import Buffers
import jarray

class Hello(GLEventListener):
    def init(self, drawable):
        pass

    def display(self, drawable):
        gl = drawable.getGL().getGL2()
        gl.glClear(GL2.GL_COLOR_BUFFER_BIT)
        
        gl.glEnableClientState(GL2.GL_COLOR_ARRAY)
        gl.glEnableClientState(GL2.GL_VERTEX_ARRAY)
        
        colors = jarray.array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], 'f')
        vertices = jarray.array([0.0, 0.5, 0.5, -0.5, -0.5, -0.5], 'f')
        
        vertexColorBuffer = Buffers.newDirectFloatBuffer(colors)
        vertexBuffer = Buffers.newDirectFloatBuffer(vertices)
        
        gl.glColorPointer(3, GL2.GL_FLOAT, 0, vertexColorBuffer)
        gl.glVertexPointer(2, GL2.GL_FLOAT, 0, vertexBuffer)
        
        gl.glDrawArrays(GL2.GL_TRIANGLE_STRIP, 0, 3)

    def dispose(self, arg0):
        pass

    def reshape(self, arg0, arg1, arg2, arg3, arg4):
        pass
    
    @staticmethod
    def main():
        profile = GLProfile.get(GLProfile.GL2)
        capabilities = GLCapabilities(profile)
        glcanvas = GLCanvas(capabilities)
        
        hello = Hello()
        glcanvas.addGLEventListener(hello)
        glcanvas.setSize(640, 480)
        
        frame = JFrame ("Hello, World!")
        frame.getContentPane().add(glcanvas)
        frame.setSize(frame.getContentPane().getPreferredSize())
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE)
        frame.setVisible(True)

if __name__ == '__main__':
    Hello.main()
