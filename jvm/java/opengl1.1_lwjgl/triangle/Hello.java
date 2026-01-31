import org.lwjgl.glfw.*;
import org.lwjgl.opengl.*;
import static org.lwjgl.glfw.GLFW.*;
import static org.lwjgl.opengl.GL11.*;
import static org.lwjgl.system.MemoryUtil.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

public class Hello {
    private long window;

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
        glfwSwapInterval(1);
        glfwShowWindow(window);
    }

    private void loop() {
        GL.createCapabilities();

        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);

        while ( !glfwWindowShouldClose(window) ) {
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

            glEnableClientState(GL_COLOR_ARRAY);
            glEnableClientState(GL_VERTEX_ARRAY);

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

            FloatBuffer vertexColorBuffer = 
                ByteBuffer
                .allocateDirect(colors.length * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer();
            vertexColorBuffer.put(colors);
            vertexColorBuffer.position(0);

            FloatBuffer vertexBuffer = 
                ByteBuffer
                .allocateDirect(vertices.length * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer();
            vertexBuffer.put(vertices);
            vertexBuffer.position(0);
            
            glColorPointer(3, GL_FLOAT, 0, vertexColorBuffer);
            glVertexPointer(2, GL_FLOAT, 0, vertexBuffer);

            glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
        
            glfwSwapBuffers(window);

            glfwPollEvents();
        }
    }

    public static void main(String[] args) {
        new Hello().run();
    }
}
