import Cocoa
import OpenGL.GL3

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

private func linkProgram(vertexShader: GLuint, fragmentShader: GLuint) -> GLuint {
    let program = glCreateProgram()
    glAttachShader(program, vertexShader)
    glAttachShader(program, fragmentShader)
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

final class TriangleView: NSOpenGLView {
    private let vertices: [GLfloat] = [
         0.0,  0.7, 0.0,
        -0.7, -0.7, 0.0,
         0.7, -0.7, 0.0
    ]

    private let colors: [GLfloat] = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    ]

    private var program: GLuint = 0
    private var vertexShader: GLuint = 0
    private var fragmentShader: GLuint = 0
    private var buffers: [GLuint] = [0, 0]
    private var positionLocation: GLint = -1
    private var colorLocation: GLint = -1

    override init(frame frameRect: NSRect) {
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAOpenGLProfile),
            NSOpenGLPixelFormatAttribute(NSOpenGLProfileVersionLegacy),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize),
            24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAlphaSize),
            8,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize),
            24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            0
        ]

        let pixelFormat = NSOpenGLPixelFormat(attributes: attrs)!
        super.init(frame: frameRect, pixelFormat: pixelFormat)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        openGLContext?.makeCurrentContext()

        if buffers[0] != 0 || buffers[1] != 0 {
            glDeleteBuffers(2, &buffers)
        }
        if program != 0 {
            glDeleteProgram(program)
        }
        if fragmentShader != 0 {
            glDeleteShader(fragmentShader)
        }
        if vertexShader != 0 {
            glDeleteShader(vertexShader)
        }
    }

    override func prepareOpenGL() {
        super.prepareOpenGL()
        openGLContext?.makeCurrentContext()

        glClearColor(0.0, 0.0, 0.0, 1.0)

        vertexShader = compileShader(type: GLenum(GL_VERTEX_SHADER), source: vertexShaderSource)
        fragmentShader = compileShader(type: GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderSource)
        program = linkProgram(vertexShader: vertexShader, fragmentShader: fragmentShader)

        positionLocation = glGetAttribLocation(program, "position")
        colorLocation = glGetAttribLocation(program, "color")

        glGenBuffers(2, &buffers)

        vertices.withUnsafeBytes { data in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[0])
            glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(data.count), data.baseAddress, GLenum(GL_STATIC_DRAW))
        }

        colors.withUnsafeBytes { data in
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[1])
            glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(data.count), data.baseAddress, GLenum(GL_STATIC_DRAW))
        }
    }

    override func reshape() {
        super.reshape()
        openGLContext?.makeCurrentContext()

        let backing = convertToBacking(bounds)
        glViewport(0, 0, GLsizei(backing.width), GLsizei(backing.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        _ = dirtyRect
        openGLContext?.makeCurrentContext()

        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glUseProgram(program)

        glEnableVertexAttribArray(GLuint(positionLocation))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[0])
        glVertexAttribPointer(GLuint(positionLocation), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)

        glEnableVertexAttribArray(GLuint(colorLocation))
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffers[1])
        glVertexAttribPointer(GLuint(colorLocation), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)

        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)

        glDisableVertexAttribArray(GLuint(colorLocation))
        glDisableVertexAttribArray(GLuint(positionLocation))

        openGLContext?.flushBuffer()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification

        let rect = NSRect(x: 0, y: 0, width: 640, height: 480)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]

        let window = NSWindow(contentRect: rect, styleMask: style, backing: .buffered, defer: false)
        window.title = "Hello, OpenGL 2.0 World!"
        window.center()

        let view = TriangleView(frame: rect)
        window.contentView = view
        window.makeKeyAndOrderFront(nil)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            view.needsDisplay = true
        }

        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        _ = sender
        return true
    }
}

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()