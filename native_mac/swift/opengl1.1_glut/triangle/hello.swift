import Foundation
import CGLUT

let vertices: [GLfloat] = [
     0.0,  0.7,
    -0.7, -0.7,
     0.7, -0.7
]

let colors: [GLfloat] = [
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0
]

func display() {
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

    glEnableClientState(GLenum(GL_VERTEX_ARRAY))
    glEnableClientState(GLenum(GL_COLOR_ARRAY))

    vertices.withUnsafeBytes { ptr in
        glVertexPointer(2, GLenum(GL_FLOAT), 0, ptr.baseAddress)
    }
    colors.withUnsafeBytes { ptr in
        glColorPointer(3, GLenum(GL_FLOAT), 0, ptr.baseAddress)
    }
    glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)

    glDisableClientState(GLenum(GL_COLOR_ARRAY))
    glDisableClientState(GLenum(GL_VERTEX_ARRAY))

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
glutCreateWindow("Hello, OpenGL 1.1 World!")
glClearColor(0.0, 0.0, 0.0, 1.0)
glutDisplayFunc(display)
glutReshapeFunc(reshape)
glutWMCloseFunc(onClose)
glutKeyboardFunc(keyboard)
glutTimerFunc(16, timer, 0)
glutMainLoop()
