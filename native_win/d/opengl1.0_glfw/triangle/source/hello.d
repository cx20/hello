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

        glBegin(GL_TRIANGLES);
            glColor3f(1.0f, 0.0f, 0.0f);  glVertex2f( 0.0f,  0.5f);
            glColor3f(0.0f, 1.0f, 0.0f);  glVertex2f( 0.5f, -0.5f);
            glColor3f(0.0f, 0.0f, 1.0f);  glVertex2f(-0.5f, -0.5f);
        glEnd();

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    return 0;
}
