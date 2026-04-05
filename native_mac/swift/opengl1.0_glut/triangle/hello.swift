import Foundation
import CGLUT

func display() {
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    glBegin(GLenum(GL_TRIANGLES))
    glColor3f(1.0, 0.0, 0.0); glVertex2f( 0.0,  0.7)
    glColor3f(0.0, 1.0, 0.0); glVertex2f(-0.7, -0.7)
    glColor3f(0.0, 0.0, 1.0); glVertex2f( 0.7, -0.7)
    glEnd()
    glutSwapBuffers()
}

func reshape(_ width: Int32, _ height: Int32) {
    glViewport(0, 0, width, height)
}

func timer(_ value: Int32) {
    glutPostRedisplay()
    glutTimerFunc(16, timer, 0)
}

func keyboard(_ key: UInt8, _ x: Int32, _ y: Int32) {
    if key == 27 || key == 113 || key == 81 { // ESC, q, Q
        exit(0)
    }
}

func onClose() {
    exit(0)
}

var argc: Int32 = CommandLine.argc
glutInit(&argc, CommandLine.unsafeArgv)
glutInitDisplayMode(UInt32(GLUT_DOUBLE) | UInt32(GLUT_RGBA))
glutInitWindowSize(640, 480)
glutCreateWindow("Hello, OpenGL 1.0 World!")
glClearColor(0.0, 0.0, 0.0, 1.0)
glutDisplayFunc(display)
glutReshapeFunc(reshape)
glutWMCloseFunc(onClose)
glutKeyboardFunc(keyboard)
glutTimerFunc(16, timer, 0)
glutMainLoop()
