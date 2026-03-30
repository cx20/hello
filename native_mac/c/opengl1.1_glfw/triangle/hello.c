#include <GLFW/glfw3.h>

static const GLfloat COLORS[] = {
    1.0f, 0.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 0.0f, 1.0f
};

static const GLfloat VERTICES[] = {
     0.0f,  0.7f,
    -0.7f, -0.7f,
     0.7f, -0.7f
};

int main(void)
{
    if (!glfwInit()) {
        return 1;
    }

    GLFWwindow* window = glfwCreateWindow(640, 480, "Hello, OpenGL 1.1 World!", NULL, NULL);
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

        glEnableClientState(GL_COLOR_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);

        glColorPointer(3, GL_FLOAT, 0, COLORS);
        glVertexPointer(2, GL_FLOAT, 0, VERTICES);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}