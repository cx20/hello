import Foundation
import CGLUT

private let vertexShaderSource = """
#version 110
attribute vec3 position;
attribute vec3 color;
varying vec3 vColor;
void main() {
    vColor = color;
    gl_Position = vec4(position, 1.0);
}
"""

private let fragmentShaderSource = """
#version 110
varying vec3 vColor;
void main() {
    gl_FragColor = vec4(vColor, 1.0);
}
"""

private func compileShader(type: GLenum, source: String) -> GLuint {
    let shader = glCreateShader(type)
    var cSource = (source as NSString).utf8String
    var length = GLint(source.utf8.count)
    glShaderSource(shader, 1, &cSource, &length)
    glCompileShader(shader)
    var status: GLint = 0
    glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
    if status == GL_FALSE {
        var logLength: GLint = 0
        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        var log = [GLchar](repeating: 0, count: Int(max(logLength, 1)))
        var actualLength: GLsizei = 0
        glGetShaderInfoLog(shader, GLsizei(log.count), &actualLength, &log)
        fatalError(String(cString: log))
    }
    return shader
}

private func linkProgram(vs: GLuint, fs: GLuint) -> GLuint {
    let prog = glCreateProgram()
    glAttachShader(prog, vs)
    glAttachShader(prog, fs)
    glLinkProgram(prog)
    var status: GLint = 0
    glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
    if status == GL_FALSE {
        var logLength: GLint = 0
        glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        var log = [GLchar](repeating: 0, count: Int(max(logLength, 1)))
        var actualLength: GLsizei = 0
        glGetProgramInfoLog(prog, GLsizei(log.count), &actualLength, &log)
        fatalError(String(cString: log))
    }
    return prog
}

var glProgram: GLuint = 0
var glVS: GLuint = 0
var glFS: GLuint = 0
var glBuffers: [GLuint] = [0, 0]
var positionLoc: GLint = 0
var colorLoc: GLint = 0

func initialize() {
    let verts: [GLfloat] = [
         0.0,  0.7, 0.0,
        -0.7, -0.7, 0.0,
         0.7, -0.7, 0.0
    ]
    let cols: [GLfloat] = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    ]

    glClearColor(0.0, 0.0, 0.0, 1.0)
    glVS = compileShader(type: GLenum(GL_VERTEX_SHADER), source: vertexShaderSource)
    glFS = compileShader(type: GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderSource)
    glProgram = linkProgram(vs: glVS, fs: glFS)

    positionLoc = glGetAttribLocation(glProgram, "position")
    colorLoc = glGetAttribLocation(glProgram, "color")

    glGenBuffers(2, &glBuffers)

    verts.withUnsafeBytes { ptr in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), glBuffers[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(ptr.count), ptr.baseAddress, GLenum(GL_STATIC_DRAW))
    }
    cols.withUnsafeBytes { ptr in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), glBuffers[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(ptr.count), ptr.baseAddress, GLenum(GL_STATIC_DRAW))
    }
}

func display() {
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    glUseProgram(glProgram)

    glEnableVertexAttribArray(GLuint(positionLoc))
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), glBuffers[0])
    glVertexAttribPointer(GLuint(positionLoc), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)

    glEnableVertexAttribArray(GLuint(colorLoc))
    glBindBuffer(GLenum(GL_ARRAY_BUFFER), glBuffers[1])
    glVertexAttribPointer(GLuint(colorLoc), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)

    glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)

    glDisableVertexAttribArray(GLuint(colorLoc))
    glDisableVertexAttribArray(GLuint(positionLoc))

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
        glDeleteBuffers(2, &glBuffers)
        glDeleteProgram(glProgram)
        glDeleteShader(glFS)
        glDeleteShader(glVS)
        exit(0)
    }
}

func onClose() {
    glDeleteBuffers(2, &glBuffers)
    glDeleteProgram(glProgram)
    glDeleteShader(glFS)
    glDeleteShader(glVS)
    exit(0)
}

var argc: Int32 = CommandLine.argc
glutInit(&argc, CommandLine.unsafeArgv)
glutInitDisplayMode(UInt32(GLUT_DOUBLE) | UInt32(GLUT_RGBA))
glutInitWindowSize(640, 480)
glutCreateWindow("Hello, OpenGL 2.0 World!")
initialize()
glutDisplayFunc(display)
glutReshapeFunc(reshape)
glutWMCloseFunc(onClose)
glutKeyboardFunc(keyboard)
glutTimerFunc(16, timer, 0)
glutMainLoop()
