#include <windows.h>
#include <tchar.h>

#define GLEW_STATIC
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <stdio.h>

GLFWwindow* window = NULL;

void InitOpenGL();
void DrawTriangle();

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    InitOpenGL();

    while ( !glfwWindowShouldClose( window ) ) {
        DrawTriangle();

        glfwPollEvents();
        glfwSwapBuffers( window );
    }

    glfwTerminate();
    return 0;
}

void InitOpenGL()
{
    glfwInit();

    window = glfwCreateWindow( 640, 480, "Hello, World!", NULL, NULL );
    glfwMakeContextCurrent( window );

    glewInit();
}

void DrawTriangle()
{
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);

    GLfloat colors[] = {
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    };
    GLfloat vertices[] = {
         0.0f,  0.5f,
         0.5f, -0.5f,
        -0.5f, -0.5f,
    };

    glColorPointer(3, GL_FLOAT, 0, colors);
    glVertexPointer(2, GL_FLOAT, 0, vertices);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
}