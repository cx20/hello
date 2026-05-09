#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

static const char *g_title   = "Hello, World!";
static const char *g_message = "Hello, X11 GUI World!";

void run_gui(void) {
    Display *display;
    Window window;
    GC gc;
    XEvent ev;
    XSizeHints hint;
    int screen;
    unsigned long foreground, background;
    int done;
    Atom atomWmDeleteWindow;

    display = XOpenDisplay("");
    screen  = DefaultScreen(display);

    foreground = BlackPixel(display, screen);
    background = WhitePixel(display, screen);
    hint.x      = 0;
    hint.y      = 0;
    hint.width  = 640;
    hint.height = 480;
    hint.flags  = PPosition | PSize;

    window = XCreateSimpleWindow(
        display,
        DefaultRootWindow(display),
        hint.x, hint.y, hint.width, hint.height,
        5,
        foreground,
        background);

    XSetStandardProperties(display, window, g_title, g_title, None, NULL, 0, &hint);

    atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    gc = XCreateGC(display, window, 0, 0);
    XSetBackground(display, gc, background);
    XSetForeground(display, gc, foreground);

    XSelectInput(display, window, ButtonPressMask | KeyPressMask | ExposureMask);
    XMapRaised(display, window);

    done = 0;
    while (done == 0) {
        XNextEvent(display, &ev);
        if (ev.type == Expose) {
            XDrawImageString(display, window, gc, 5, 20, g_message, strlen(g_message));
        }
        if (ev.type == ClientMessage) {
            if (ev.xclient.data.l[0] == (long)atomWmDeleteWindow) {
                break;
            }
        } else if (ev.type == DestroyNotify) {
            break;
        }
    }

    XFreeGC(display, gc);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
}
