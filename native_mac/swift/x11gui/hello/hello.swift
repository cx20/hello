import CX11

// X11 event type and mask constants (C macros, not available directly in Swift)
private let xExpose: Int32        = 12
private let xDestroyNotify: Int32 = 17
private let xClientMessage: Int32 = 33
private let xPPosition: Int       = 4      // 1 << 2
private let xPSize: Int           = 8      // 1 << 3
private let xKeyPressMask: Int    = 1      // 1 << 0
private let xButtonPressMask: Int = 4      // 1 << 2
private let xExposureMask: Int    = 32768  // 1 << 15

func main() {
    guard let display = XOpenDisplay(nil) else {
        fputs("Failed to open X display. Start XQuartz and set DISPLAY.\n", stderr)
        exit(1)
    }

    let screen = XDefaultScreen(display)
    let foreground = XBlackPixel(display, screen)
    let background = XWhitePixel(display, screen)

    var hint = XSizeHints()
    hint.x = 0; hint.y = 0; hint.width = 640; hint.height = 480
    hint.flags = xPPosition | xPSize

    let window = XCreateSimpleWindow(
        display, XDefaultRootWindow(display),
        0, 0, 640, 480, 5, foreground, background)

    "Hello, World!".withCString { title in
        XSetStandardProperties(display, window, title, title, 0, nil, 0, &hint)
    }

    let atomWmDeleteWindow = "WM_DELETE_WINDOW".withCString {
        XInternAtom(display, $0, 0)
    }
    var protocols = [atomWmDeleteWindow]
    protocols.withUnsafeMutableBufferPointer {
        _ = XSetWMProtocols(display, window, $0.baseAddress, 1)
    }

    let gc = XCreateGC(display, window, 0, nil)
    XSetBackground(display, gc, background)
    XSetForeground(display, gc, foreground)
    XSelectInput(display, window, xKeyPressMask | xButtonPressMask | xExposureMask)
    XMapRaised(display, window)

    let message = "Hello, X11 GUI World!"
    var done = false
    while !done {
        var ev = XEvent()
        XNextEvent(display, &ev)
        switch ev.type {
        case xExpose:
            message.withCString {
                XDrawImageString(display, window, gc, 5, 20, $0, Int32(message.utf8.count))
            }
        case xClientMessage:
            if ev.xclient.data.l.0 == Int(atomWmDeleteWindow) {
                done = true
            }
        case xDestroyNotify:
            done = true
        default:
            break
        }
    }

    XFreeGC(display, gc)
    XDestroyWindow(display, window)
    XCloseDisplay(display)
}

main()
