from java.lang import System
from javax.swing import JFrame
from com.jogamp.opengl import GL2
from com.jogamp.opengl import GLAutoDrawable
from com.jogamp.opengl import GLCapabilities
from com.jogamp.opengl import GLEventListener
from com.jogamp.opengl import GLProfile
from com.jogamp.opengl.awt import GLCanvas

class Hello(GLEventListener):
    def init(self, drawable):
        pass

    def display(self, drawable):
        gl = drawable.getGL().getGL2()
        gl.glClear(GL2.GL_COLOR_BUFFER_BIT)
        gl.glBegin(GL2.GL_TRIANGLES)
        gl.glColor3f( 1, 0, 0 )
        gl.glVertex2f( 0.0,  0.5 )
        gl.glColor3f( 0, 1, 0 )
        gl.glVertex2f( 0.5, -0.5 )
        gl.glColor3f( 0, 0, 1 )
        gl.glVertex2f(-0.5, -0.5 )
        gl.glEnd()

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
