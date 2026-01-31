import javax.swing.JFrame;
import com.jogamp.opengl.GL2;
import com.jogamp.opengl.GLAutoDrawable;
import com.jogamp.opengl.GLCapabilities;
import com.jogamp.opengl.GLEventListener;
import com.jogamp.opengl.GLProfile;
import com.jogamp.opengl.awt.GLCanvas;
import com.jogamp.common.nio.Buffers;
import java.nio.FloatBuffer;

public class Hello implements GLEventListener {
   public void init(GLAutoDrawable drawable) {
   }

   public void display(GLAutoDrawable drawable) {
        GL2 gl = drawable.getGL().getGL2();
        gl.glClear(GL2.GL_COLOR_BUFFER_BIT);

        float[] colors = {  
             1.0f,  0.0f,  0.0f,
             0.0f,  1.0f,  0.0f,
             0.0f,  0.0f,  1.0f
        };
        float[] vertices = {  
             0.0f,  0.5f,  0.0f,
             0.5f, -0.5f,  0.0f,
            -0.5f, -0.5f,  0.0f
        };

        String vertexSource =
            "attribute vec3 position;                     \n" + 
            "attribute vec3 color;                        \n" + 
            "varying   vec4 vColor;                       \n" + 
            "void main()                                  \n" + 
            "{                                            \n" + 
            "  vColor = vec4(color, 1.0);                 \n" + 
            "  gl_Position = vec4(position, 1.0);         \n" + 
            "}                                            \n";
        String fragmentSource =
            "precision mediump float;                     \n" + 
            "varying   vec4 vColor;                       \n" + 
            "void main()                                  \n" + 
            "{                                            \n" + 
            "  gl_FragColor = vColor;                     \n" + 
            "}                                            \n";

        int[] vbo = new int[2];
        gl.glGenBuffers(2, vbo, 0);
        
        FloatBuffer vertexBuffer = Buffers.newDirectFloatBuffer(vertices);
        FloatBuffer vertexColorBuffer = Buffers.newDirectFloatBuffer(colors);

        gl.glBindBuffer(GL2.GL_ARRAY_BUFFER, vbo[0]);
        gl.glBufferData(GL2.GL_ARRAY_BUFFER, 4 * vertices.length, vertexBuffer, GL2.GL_STATIC_DRAW);

        gl.glBindBuffer(GL2.GL_ARRAY_BUFFER, vbo[1]);
        gl.glBufferData(GL2.GL_ARRAY_BUFFER, 4 * colors.length, vertexColorBuffer, GL2.GL_STATIC_DRAW);

        int vs = gl.glCreateShader(GL2.GL_VERTEX_SHADER);
        int fs = gl.glCreateShader(GL2.GL_FRAGMENT_SHADER);

        String[] vsrc = new String[] { vertexSource };
        int[] vlengths = new int[] { vsrc[0].length() };
        gl.glShaderSource(vs, 1, vsrc, vlengths, 0);
        gl.glCompileShader(vs);

        String[] fsrc = new String[] { fragmentSource };
        int[] flengths = new int[] { fsrc[0].length() };
        gl.glShaderSource(fs, 1, fsrc, flengths, 0);
        gl.glCompileShader(fs);

        int program = gl.glCreateProgram();
        gl.glAttachShader(program, vs);
        gl.glAttachShader(program, fs);
        gl.glLinkProgram(program);
        gl.glUseProgram(program); 

        int posAttrib = gl.glGetAttribLocation(program, "position");
        gl.glEnableVertexAttribArray(posAttrib);

        int colAttrib = gl.glGetAttribLocation(program, "color");
        gl.glEnableVertexAttribArray(colAttrib);

        gl.glBindBuffer(GL2.GL_ARRAY_BUFFER, vbo[0]);
        gl.glVertexAttribPointer(posAttrib, 3, GL2.GL_FLOAT, false, 0, 0);

        gl.glBindBuffer(GL2.GL_ARRAY_BUFFER, vbo[1]);
        gl.glVertexAttribPointer(colAttrib, 3, GL2.GL_FLOAT, false, 0, 0);
        
        gl.glDrawArrays(GL2.GL_TRIANGLES, 0, 3);
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
