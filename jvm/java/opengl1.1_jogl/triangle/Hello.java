import javax.swing.JFrame;
import com.jogamp.opengl.GL2;
import com.jogamp.opengl.GLAutoDrawable;
import com.jogamp.opengl.GLCapabilities;
import com.jogamp.opengl.GLEventListener;
import com.jogamp.opengl.GLProfile;
import com.jogamp.opengl.awt.GLCanvas;
import com.jogamp.common.nio.Buffers;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

public class Hello implements GLEventListener {
   public void init(GLAutoDrawable drawable) {
   }

   public void display(GLAutoDrawable drawable) {
        GL2 gl = drawable.getGL().getGL2();
        gl.glClear(GL2.GL_COLOR_BUFFER_BIT);

        gl.glEnableClientState(GL2.GL_COLOR_ARRAY);
        gl.glEnableClientState(GL2.GL_VERTEX_ARRAY);

        float[] colors = {  
             1.0f,  0.0f,  0.0f,
             0.0f,  1.0f,  0.0f,
             0.0f,  0.0f,  1.0f
        };
        float[] vertices = {  
             0.0f,  0.5f,
             0.5f, -0.5f,
            -0.5f, -0.5f,
        };
        FloatBuffer vertexColorBuffer = Buffers.newDirectFloatBuffer(colors);
        FloatBuffer vertexBuffer = Buffers.newDirectFloatBuffer(vertices);

        gl.glColorPointer(3, GL2.GL_FLOAT, 0, vertexColorBuffer);
        gl.glVertexPointer(2, GL2.GL_FLOAT, 0, vertexBuffer);

        gl.glDrawArrays(GL2.GL_TRIANGLE_STRIP, 0, 3);
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
