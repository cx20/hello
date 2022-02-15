import javax.swing.JFrame;
import com.jogamp.opengl.GL2;
import com.jogamp.opengl.GLAutoDrawable;
import com.jogamp.opengl.GLCapabilities;
import com.jogamp.opengl.GLEventListener;
import com.jogamp.opengl.GLProfile;
import com.jogamp.opengl.awt.GLCanvas;

public class Hello implements GLEventListener {
   public void init(GLAutoDrawable drawable) {
   }

   public void display(GLAutoDrawable drawable) {
        GL2 gl = drawable.getGL().getGL2();
        gl.glClear(GL2.GL_COLOR_BUFFER_BIT);
        gl.glBegin(GL2.GL_TRIANGLES);
        gl.glColor3f( 1, 0, 0 ); gl.glVertex2f(  0.0f,  0.5f );
        gl.glColor3f( 0, 1, 0 ); gl.glVertex2f(  0.5f, -0.5f );
        gl.glColor3f( 0, 0, 1 ); gl.glVertex2f( -0.5f, -0.5f );
        gl.glEnd();
   }

   public void dispose(GLAutoDrawable arg0) {
   }

   public void reshape(GLAutoDrawable arg0, int arg1, int arg2, int arg3, int arg4) {
   }

   public static void main(String[] args) {
      final GLProfile profile = GLProfile.get(GLProfile.GL2);
      GLCapabilities capabilities = new GLCapabilities(profile);
      final GLCanvas glcanvas = new GLCanvas(capabilities);

      Hello hello = new Hello();
      glcanvas.addGLEventListener(hello);
      glcanvas.setSize(640, 480);

      final JFrame frame = new JFrame ("Hello, World!");
      frame.getContentPane().add(glcanvas);
      frame.setSize(frame.getContentPane().getPreferredSize());
      frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
      frame.setVisible(true);
   }
}
