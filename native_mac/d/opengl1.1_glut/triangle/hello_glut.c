#include <GLUT/glut.h>
#include <stdlib.h>

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

static void Display(void)
{
    glClear(GL_COLOR_BUFFER_BIT);

    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);

    glColorPointer(3, GL_FLOAT, 0, COLORS);
    glVertexPointer(2, GL_FLOAT, 0, VERTICES);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);

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
    glutCreateWindow("Hello, OpenGL 1.1 World!");

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

    glutDisplayFunc(Display);
    glutReshapeFunc(Reshape);
    glutWMCloseFunc(OnClose);
    glutKeyboardFunc(Keyboard);
    glutTimerFunc(16, Timer, 0);
    glutMainLoop();
}
