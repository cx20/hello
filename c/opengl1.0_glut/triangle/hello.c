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

void DrawTriangle(void
{
    glBegin(GL_TRIANGLES);

        glColor3f(1.0f, 0.0f, 0.0f);   glVertex2f( 0.0f,  0.50f);
        glColor3f(0.0f, 1.0f, 0.0f);   glVertex2f( 0.5f, -0.50f);
        glColor3f(0.0f, 0.0f, 1.0f);   glVertex2f(-0.5f, -0.50f);

    glEnd();
    
    glFlush();
}
