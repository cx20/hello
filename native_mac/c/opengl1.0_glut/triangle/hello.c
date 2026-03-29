#include <GLUT/glut.h>

#include <stdlib.h>

void Display(void)
{
    glClear(GL_COLOR_BUFFER_BIT);

    glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f); glVertex2f( 0.0f,  0.7f);
        glColor3f(0.0f, 1.0f, 0.0f); glVertex2f(-0.7f, -0.7f);
        glColor3f(0.0f, 0.0f, 1.0f); glVertex2f( 0.7f, -0.7f);
    glEnd();

    glutSwapBuffers();
}

void Reshape(int width, int height)
{
    glViewport(0, 0, width, height);
}

void Timer(int value)
{
    glutPostRedisplay();
    glutTimerFunc(16, Timer, 0);
}

void OnClose(void)
{
    exit(0);
}

int main(int argc, char** argv)
{
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA);
    glutInitWindowSize(640, 480);
    glutCreateWindow("Hello, OpenGL 1.0 World!");

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

    glutDisplayFunc(Display);
    glutReshapeFunc(Reshape);
    glutWMCloseFunc(OnClose);
    glutTimerFunc(16, Timer, 0);
    glutMainLoop();

    return 0;
}
