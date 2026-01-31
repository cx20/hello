#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int main(int argc, char * argv[]) {
    /* setup display/screen */
    Display* display = XOpenDisplay("");
    int screen = DefaultScreen(display);

    /* drawing contexts for an window */
    unsigned long foreground = BlackPixel(display, screen);
    unsigned long background = WhitePixel(display, screen);
    XSizeHints hint;
    hint.x = 0;
    hint.y = 0;
    hint.width = 640;
    hint.height = 480;
    hint.flags = PPosition | PSize;

    /* create window */
    Window window = XCreateSimpleWindow(
        display,
        DefaultRootWindow(display),
        hint.x,
        hint.y,
        hint.width,
        hint.height,
        5,
        foreground, 
        background);

    /* window manager properties (yes, use of StdProp is obsolete) */
    char helloTitle[] = "Hello, World!";
    XSetStandardProperties(display, window, helloTitle, helloTitle, None, argv, argc, & hint);

    Atom atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    /* graphics context */
    GC gc = XCreateGC(display, window, 0, 0);
    XSetBackground(display, gc, background);
    XSetForeground(display, gc, foreground);

    /* allow receiving mouse events */
    XSelectInput(display, window, ButtonPressMask | KeyPressMask | ExposureMask);

    /* show up window */
    XMapRaised(display, window);
    
    /* event loop */
    XEvent ev;
    int done = 0;
    while (done == 0) {
        XNextEvent(display, &ev);
        if (ev.type == Expose) {
            char helloMessage[] = "Hello, X11 GUI(C++) World!";
            XDrawImageString(display, window, gc, 5, 20, helloMessage, strlen(helloMessage));
        }
        if (ev.type == ClientMessage) {
            if (ev.xclient.data.l[0] == atomWmDeleteWindow) {
                break;
            }
        }
        else if (ev.type == DestroyNotify) { 
            break;
        }
    }

    /* finalization */
    XFreeGC(display, gc);
    XDestroyWindow(display, window);
    XCloseDisplay(display);

    exit(0);
}