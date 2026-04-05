#include <GLUT/glut.h>
#include <stdlib.h>

static void Display(void)
{
    glClear(GL_COLOR_BUFFER_BIT);

    glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f); glVertex2f( 0.0f,  0.7f);
        glColor3f(0.0f, 1.0f, 0.0f); glVertex2f(-0.7f, -0.7f);
        glColor3f(0.0f, 0.0f, 1.0f); glVertex2f( 0.7f, -0.7f);
    glEnd();

    glutSwapBuffers();
}

static void Reshape(int width, int height)
{
    glViewport(0, 0, width, height);
}

static void Timer(int value)
{
    (void)value;
    glutPostRedisplay();
    glutTimerFunc(16, Timer, 0);
}

static void OnClose(void)
{
    exit(0);
}

static void Keyboard(unsigned char key, int x, int y)
{
    (void)x;
    (void)y;
    if (key == 27 || key == 'q' || key == 'Q') {
        exit(0);
    }
}

void runSample(void)
{
    int argc = 0;
    glutInit(&argc, NULL);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA);
    glutInitWindowSize(640, 480);
    glutCreateWindow("Hello, OpenGL 1.0 World!");

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

    glutDisplayFunc(Display);
    glutReshapeFunc(Reshape);
    glutWMCloseFunc(OnClose);
    glutKeyboardFunc(Keyboard);
    glutTimerFunc(16, Timer, 0);
    glutMainLoop();
}
