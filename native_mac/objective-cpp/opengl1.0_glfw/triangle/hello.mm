#import <GLFW/glfw3.h>

int main(void)
{
    if (!glfwInit()) {
        return 1;
    }

    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, OpenGL 1.0 World!", NULL, NULL);
    if (!window) {
        glfwTerminate();
        return 1;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    while (!glfwWindowShouldClose(window)) {
        int width = 0;
        int height = 0;
        glfwGetFramebufferSize(window, &width, &height);
        glViewport(0, 0, width, height);

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glBegin(GL_TRIANGLES);
            glColor3f(1.0f, 0.0f, 0.0f); glVertex2f( 0.0f,  0.7f);
            glColor3f(0.0f, 1.0f, 0.0f); glVertex2f(-0.7f, -0.7f);
            glColor3f(0.0f, 0.0f, 1.0f); glVertex2f( 0.7f, -0.7f);
        glEnd();

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}