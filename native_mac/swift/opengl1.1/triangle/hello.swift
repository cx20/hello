import Cocoa
import OpenGL.GL

final class TriangleView: NSOpenGLView {
    private let colors: [GLfloat] = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0
    ]

    private let vertices: [GLfloat] = [
         0.0,  0.7,
        -0.7, -0.7,
         0.7, -0.7
    ]

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

    override func prepareOpenGL() {
        super.prepareOpenGL()
        openGLContext?.makeCurrentContext()
        glClearColor(0.0, 0.0, 0.0, 1.0)
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

        glEnableClientState(GLenum(GL_COLOR_ARRAY))
        glEnableClientState(GLenum(GL_VERTEX_ARRAY))

        colors.withUnsafeBufferPointer { colorBuffer in
            vertices.withUnsafeBufferPointer { vertexBuffer in
                glColorPointer(3, GLenum(GL_FLOAT), 0, colorBuffer.baseAddress)
                glVertexPointer(2, GLenum(GL_FLOAT), 0, vertexBuffer.baseAddress)
                glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
            }
        }

        glDisableClientState(GLenum(GL_VERTEX_ARRAY))
        glDisableClientState(GLenum(GL_COLOR_ARRAY))

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
        window.title = "Hello, OpenGL 1.1 World!"
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