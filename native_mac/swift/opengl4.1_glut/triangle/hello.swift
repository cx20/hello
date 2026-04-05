import Foundation
import CGLUT

private let vertexShaderSource = """
#version 410 core
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;
out vec3 vColor;
void main() {
    vColor = color;
    gl_Position = vec4(position, 1.0);
}
"""

private let fragmentShaderSource = """
#version 410 core
in vec3 vColor;
out vec4 outColor;
void main() {
    outColor = vec4(vColor, 1.0);
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
var glVertexArray: GLuint = 0
var glBuffers: [GLuint] = [0, 0]

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

    glGenVertexArrays(1, &glVertexArray)
    glBindVertexArray(glVertexArray)

    glGenBuffers(2, &glBuffers)

    verts.withUnsafeBytes { ptr in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), glBuffers[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(ptr.count), ptr.baseAddress, GLenum(GL_STATIC_DRAW))
        glVertexAttribPointer(0, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(0)
    }

    cols.withUnsafeBytes { ptr in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), glBuffers[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(ptr.count), ptr.baseAddress, GLenum(GL_STATIC_DRAW))
        glVertexAttribPointer(1, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(1)
    }

    glBindVertexArray(0)
}

func display() {
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    glUseProgram(glProgram)
    glBindVertexArray(glVertexArray)
    glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    glBindVertexArray(0)
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
        glDeleteVertexArrays(1, &glVertexArray)
        glDeleteProgram(glProgram)
        glDeleteShader(glFS)
        glDeleteShader(glVS)
        exit(0)
    }
}

func onClose() {
    glDeleteBuffers(2, &glBuffers)
    glDeleteVertexArrays(1, &glVertexArray)
    glDeleteProgram(glProgram)
    glDeleteShader(glFS)
    glDeleteShader(glVS)
    exit(0)
}

var argc: Int32 = CommandLine.argc
glutInit(&argc, CommandLine.unsafeArgv)
glutInitDisplayMode(UInt32(GLUT_DOUBLE) | UInt32(GLUT_RGBA) | 0x0004)
glutInitWindowSize(640, 480)
glutCreateWindow("Hello, OpenGL 4.1 World!")
initialize()
glutDisplayFunc(display)
glutReshapeFunc(reshape)
glutWMCloseFunc(onClose)
glutKeyboardFunc(keyboard)
glutTimerFunc(16, timer, 0)
glutMainLoop()
