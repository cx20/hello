import core.sys.windows.windef;
import bindbc.glfw;
import bindbc.opengl;

extern(Windows)
int WinMain(HINSTANCE /* hInstance */, HINSTANCE /* hPrevInstance */, LPSTR /* lpCmdLine */, int /* nCmdShow */)
{
    const GLFWSupport ret = loadGLFW();
    if (ret != glfwSupport) {
        return 1;
    }

    if (!glfwInit()) {
        return 1;
    }
    scope(exit) glfwTerminate();

    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, World!", null, null);
    if (window is null) {
        return 1;
    }
    glfwMakeContextCurrent(window);

    loadOpenGL();

    while (!glfwWindowShouldClose(window)) {
        glClearColor(0f, 0f, 0f, 1f);
        glClear(GL_COLOR_BUFFER_BIT);

        glEnableClientState(GL_COLOR_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);

        float[] colors = [
             1.0f,  0.0f,  0.0f,
             0.0f,  1.0f,  0.0f,
             0.0f,  0.0f,  1.0f
        ];
        float[] vertices = [
             0.0f,  0.5f,
             0.5f, -0.5f,
            -0.5f, -0.5f,
        ];

        glColorPointer(3, GL_FLOAT, 0, cast(void*)colors);
        glVertexPointer(2, GL_FLOAT, 0, cast(void*)vertices);

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    return 0;
}
