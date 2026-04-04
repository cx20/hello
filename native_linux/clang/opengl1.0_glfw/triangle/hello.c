#include <GLFW/glfw3.h>

GLFWwindow* window = NULL;

void InitOpenGL();
void DrawTriangle();

int main(int argc, char** argv)
{
    InitOpenGL();

    while (!glfwWindowShouldClose(window)) {
        DrawTriangle();

        glfwPollEvents();
        glfwSwapBuffers(window);
    }

    glfwTerminate();
    return 0;
}

void InitOpenGL()
{
    glfwInit();

    window = glfwCreateWindow(640, 480, "Hello, World!", NULL, NULL);
    glfwMakeContextCurrent(window);
}

void DrawTriangle()
{
    glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f);   glVertex2f( 0.0f,  0.50f);
        glColor3f(0.0f, 1.0f, 0.0f);   glVertex2f( 0.5f, -0.50f);
        glColor3f(0.0f, 0.0f, 1.0f);   glVertex2f(-0.5f, -0.50f);
    glEnd();
}