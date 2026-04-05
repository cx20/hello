import Foundation
import GLFW

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
    let program = glCreateProgram()
    glAttachShader(program, vs)
    glAttachShader(program, fs)
    glLinkProgram(program)
    var status: GLint = 0
    glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
    if status == GL_FALSE {
        var logLength: GLint = 0
        glGetProgramiv(program, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        var log = [GLchar](repeating: 0, count: Int(max(logLength, 1)))
        var actualLength: GLsizei = 0
        glGetProgramInfoLog(program, GLsizei(log.count), &actualLength, &log)
        fatalError(String(cString: log))
    }
    return program
}

func main() {
    guard glfwInit() != 0 else {
        fputs("Failed to initialize GLFW\n", stderr)
        exit(1)
    }
    defer { glfwTerminate() }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1)

    guard let window = glfwCreateWindow(640, 480, "Hello, OpenGL 2.0 World!", nil, nil) else {
        fputs("Failed to create GLFW window\n", stderr)
        exit(1)
    }
    defer { glfwDestroyWindow(window) }

    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)

    let vs = compileShader(type: GLenum(GL_VERTEX_SHADER), source: vertexShaderSource)
    let fs = compileShader(type: GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderSource)
    let program = linkProgram(vs: vs, fs: fs)

    let vertices: [GLfloat] = [
         0.0,  0.7, 0.0,
        -0.7, -0.7, 0.0,
         0.7, -0.7, 0.0
    ]
    let colors: [GLfloat] = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    ]

    var buffers: [GLuint] = [0, 0]
    glGenBuffers(2, &buffers)

    vertices.withUnsafeBytes { ptr in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(ptr.count), ptr.baseAddress, GLenum(GL_STATIC_DRAW))
    }
    colors.withUnsafeBytes { ptr in
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(ptr.count), ptr.baseAddress, GLenum(GL_STATIC_DRAW))
    }

    let positionLoc = glGetAttribLocation(program, "position")
    let colorLoc = glGetAttribLocation(program, "color")

    while glfwWindowShouldClose(window) == 0 {
        var width: Int32 = 0
        var height: Int32 = 0
        glfwGetFramebufferSize(window, &width, &height)
        glViewport(0, 0, width, height)

        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glUseProgram(program)

        glEnableVertexAttribArray(GLuint(positionLoc))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[0])
        glVertexAttribPointer(GLuint(positionLoc), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)

        glEnableVertexAttribArray(GLuint(colorLoc))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[1])
        glVertexAttribPointer(GLuint(colorLoc), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)

        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)

        glDisableVertexAttribArray(GLuint(colorLoc))
        glDisableVertexAttribArray(GLuint(positionLoc))

        glfwSwapBuffers(window)
        glfwPollEvents()
    }

    glDeleteBuffers(2, &buffers)
    glDeleteProgram(program)
    glDeleteShader(fs)
    glDeleteShader(vs)
}

main()
