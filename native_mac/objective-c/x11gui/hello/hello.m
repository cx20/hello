#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int main(int argc, char *argv[])
{
    char helloTitle[] = "Hello, World!";
    char helloMessage[] = "Hello, X11 GUI(Objective-C) World!";
    Display *display = XOpenDisplay(NULL);
    Window window;
    GC gc;
    XEvent ev;
    XSizeHints hint;
    int screen;
    unsigned long foreground;
    unsigned long background;
    Atom atomWmDeleteWindow;

    if (display == NULL) {
        fprintf(stderr, "Failed to open X display. Start XQuartz and set DISPLAY.\n");
        return 1;
    }

    screen = DefaultScreen(display);
    foreground = BlackPixel(display, screen);
    background = WhitePixel(display, screen);

    hint.x = 0;
    hint.y = 0;
    hint.width = 640;
    hint.height = 480;
    hint.flags = PPosition | PSize;

    window = XCreateSimpleWindow(
        display,
        DefaultRootWindow(display),
        hint.x,
        hint.y,
        hint.width,
        hint.height,
        1,
        foreground,
        background);

    XSetStandardProperties(display, window, helloTitle, helloTitle, None, argv, argc, &hint);

    atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    gc = XCreateGC(display, window, 0, 0);
    XSetBackground(display, gc, background);
    XSetForeground(display, gc, foreground);
    XSelectInput(display, window, KeyPressMask | ExposureMask | StructureNotifyMask);

    XMapRaised(display, window);

    for (;;) {
        XNextEvent(display, &ev);

        if (ev.type == Expose) {
            XDrawImageString(display, window, gc, 5, 20, helloMessage, (int)strlen(helloMessage));
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