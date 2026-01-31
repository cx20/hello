import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL20.*;
import static org.lwjgl.system.MemoryUtil.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

public class Hello {
    private long window;
    private int program;
    private int vbo0;
    private int vbo1;
    private int posAttrib;
    private int colAttrib;

    public void run() {
        init();
        loop();

        glfwDestroyWindow(window);
        glfwTerminate();
    }

    private void init() {
        glfwInit();

        glfwDefaultWindowHints();
        glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
        glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

        window = glfwCreateWindow(640, 480, "Hello, World!", NULL, NULL);

        glfwSetKeyCallback(window, (window, key, scancode, action, mods) -> {
            if ( key == GLFW_KEY_ESCAPE && action == GLFW_RELEASE )
                glfwSetWindowShouldClose(window, true);
        });

        glfwMakeContextCurrent(window);

        initShader();
        initBuffer();

        glfwSwapInterval(1);
        glfwShowWindow(window);
    }
    
    private void initShader() {
        GL.createCapabilities();

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

        int vs = glCreateShader(GL_VERTEX_SHADER);
        int fs = glCreateShader(GL_FRAGMENT_SHADER);

        glShaderSource(vs, vertexSource);
        glCompileShader(vs);

        glShaderSource(fs, fragmentSource);
        glCompileShader(fs);

        program = glCreateProgram();
        glAttachShader(program, vs);
        glAttachShader(program, fs);
        glLinkProgram(program);
        glUseProgram(program); 

        posAttrib = glGetAttribLocation(program, "position");
        glEnableVertexAttribArray(posAttrib);

        colAttrib = glGetAttribLocation(program, "color");
        glEnableVertexAttribArray(colAttrib);
    }
    
    private void initBuffer() {
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

        vbo0 = glGenBuffers();
        vbo1 = glGenBuffers();

        glBindBuffer(GL_ARRAY_BUFFER, vbo0);
        glBufferData(GL_ARRAY_BUFFER, vertices, GL_STATIC_DRAW);

        glBindBuffer(GL_ARRAY_BUFFER, vbo1);
        glBufferData(GL_ARRAY_BUFFER, colors, GL_STATIC_DRAW);
    }

    private void loop() {

        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);

        while ( !glfwWindowShouldClose(window) ) {
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            glBindBuffer(GL_ARRAY_BUFFER, vbo0);
            glVertexAttribPointer(posAttrib, 3, GL_FLOAT, false, 0, 0);

            glBindBuffer(GL_ARRAY_BUFFER, vbo1);
            glVertexAttribPointer(colAttrib, 3, GL_FLOAT, false, 0, 0);
            
            glDrawArrays(GL_TRIANGLES, 0, 3);
        
            glfwSwapBuffers(window);
            glfwPollEvents();
        }
    }

    public static void main(String[] args) {
        new Hello().run();
    }
}
