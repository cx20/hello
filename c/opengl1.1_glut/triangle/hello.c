#include <windows.h>
#include <tchar.h>
#include "glut.h"

void DrawTriangle(void);

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    glutInit(&__argc, __argv);
    glutInitWindowSize(640, 480);
    glutCreateWindow("Hello, World!");
    glutDisplayFunc(DrawTriangle);
    glutMainLoop();

    return 0;
}

void DrawTriangle(void)
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
    
    glFlush();
}
