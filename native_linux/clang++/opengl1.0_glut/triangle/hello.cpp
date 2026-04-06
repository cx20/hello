#include <GL/glut.h>
#include <cstdlib>

static void Display()
{
    glClear(GL_COLOR_BUFFER_BIT);
    glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f); glVertex2f( 0.0f,  0.7f);
        glColor3f(0.0f, 1.0f, 0.0f); glVertex2f(-0.7f, -0.7f);
        glColor3f(0.0f, 0.0f, 1.0f); glVertex2f( 0.7f, -0.7f);
    glEnd();
    glutSwapBuffers();
}

static void Reshape(int width, int height) { glViewport(0, 0, width, height); }
static void Timer(int value) { (void)value; glutPostRedisplay(); glutTimerFunc(16, Timer, 0); }
static void OnClose() { std::exit(0); }
static void Keyboard(unsigned char key, int, int) { if (key==27||key=='q'||key=='Q') std::exit(0); }

int main(int argc, char** argv)
{
    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA);
    glutInitWindowSize(640, 480);
    glutCreateWindow("Hello, OpenGL 1.0 World!");
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glutDisplayFunc(Display);
    glutReshapeFunc(Reshape);
    glutCloseFunc(OnClose);
    glutKeyboardFunc(Keyboard);
    glutTimerFunc(16, Timer, 0);
    glutMainLoop();
    return 0;
}
