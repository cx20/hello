use strict;
use OpenGL ':all';

sub displayFunc
{
	glClear(GL_COLOR_BUFFER_BIT);

	glBegin(GL_TRIANGLES);

        glColor3f(1.0, 0.0, 0.0);   glVertex2f( 0.0,  0.50);
        glColor3f(0.0, 1.0, 0.0);   glVertex2f( 0.5, -0.50);
        glColor3f(0.0, 0.0, 1.0);   glVertex2f(-0.5, -0.50);

	glEnd();

	glutSwapBuffers();
}

glutInit();
glutInitDisplayMode(GLUT_DOUBLE);
glutInitWindowSize(640, 480);
glutCreateWindow("Hello, World!");
glutDisplayFunc(\&displayFunc);
glutIdleFunc(sub{glutPostRedisplay();});
glutMainLoop();
