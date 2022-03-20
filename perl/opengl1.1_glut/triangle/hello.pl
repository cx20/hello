use strict;
use OpenGL qw(:all);

sub displayFunc
{
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);

    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);
    
    my @colors = (
         1.0,  0.0,  0.0,
         0.0,  1.0,  0.0,
         0.0,  0.0,  1.0
    );
    
    my @vertices = (
         0.0,  0.5, 0.0,
         0.5, -0.5, 0.0,
        -0.5, -0.5, 0.0
    );

    my $colors = OpenGL::Array->new_list(GL_FLOAT, @colors);
    my $vertices = OpenGL::Array->new_list(GL_FLOAT, @vertices);
    
    glColorPointer_p(3, $colors);
    glVertexPointer_p(3, $vertices);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
    
    glutSwapBuffers();
}

glutInit();
glutInitDisplayMode(GLUT_DOUBLE);
glutInitWindowSize(640, 480);
glutCreateWindow("Hello, World!");
glutDisplayFunc(\&displayFunc);
glutIdleFunc(sub{glutPostRedisplay();});
glutMainLoop();
