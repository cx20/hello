#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int main(int argc, char *argv[])
{
    const char helloTitle[] = "Hello, World!";
    const char helloMessage[] = "Hello, X11 GUI(Objective-C++) World!";
    Display *display = XOpenDisplay(NULL);
    XSizeHints hint;
    XEvent ev;

    if (display == NULL) {
        std::fprintf(stderr, "Failed to open X display. Start XQuartz and set DISPLAY.\n");
        return 1;
    }

    int screen = DefaultScreen(display);
    unsigned long foreground = BlackPixel(display, screen);
    unsigned long background = WhitePixel(display, screen);

    hint.x = 0;
    hint.y = 0;
    hint.width = 640;
    hint.height = 480;
    hint.flags = PPosition | PSize;

    Window window = XCreateSimpleWindow(
        display,
        DefaultRootWindow(display),
        hint.x,
        hint.y,
        hint.width,
        hint.height,
        1,
        foreground,
        background);

    XSetStandardProperties(display, window, const_cast<char *>(helloTitle), const_cast<char *>(helloTitle), None, argv, argc, &hint);

    Atom atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    GC gc = XCreateGC(display, window, 0, 0);
    XSetBackground(display, gc, background);
    XSetForeground(display, gc, foreground);
    XSelectInput(display, window, KeyPressMask | ExposureMask | StructureNotifyMask);

    XMapRaised(display, window);

    for (;;) {
        XNextEvent(display, &ev);

        if (ev.type == Expose) {
            XDrawImageString(display, window, gc, 5, 20, helloMessage, static_cast<int>(std::strlen(helloMessage)));
        } else if (ev.type == ClientMessage) {
            if ((Atom)ev.xclient.data.l[0] == atomWmDeleteWindow) {
                break;
            }
        } else if (ev.type == DestroyNotify) {
            break;
        }
    }

    XFreeGC(display, gc);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
    return 0;
}