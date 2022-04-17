#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

int main(int argc, char * argv[]) {
    char helloTitle[] = "Hello, World!";
    char helloMessage[] = "Hello, X11 GUI World!";
    Display * display;
    Window window;
    GC gc;
    XEvent ev;
    XSizeHints hint;
    int screen;
    unsigned long foreground, background;
    int i;
    int done;
    Atom atomWmDeleteWindow;

    /* setup display/screen */
    display = XOpenDisplay("");
    screen = DefaultScreen(display);

    /* drawing contexts for an window */
    foreground = BlackPixel(display, screen);
    background = WhitePixel(display, screen);
    hint.x = 0;
    hint.y = 0;
    hint.width = 640;
    hint.height = 480;
    hint.flags = PPosition | PSize;

    /* create window */
    window = XCreateSimpleWindow(
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
    XSetStandardProperties(display, window, helloTitle, helloTitle, None, argv, argc, & hint);

    atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    /* graphics context */
    gc = XCreateGC(display, window, 0, 0);
    XSetBackground(display, gc, background);
    XSetForeground(display, gc, foreground);

    /* allow receiving mouse events */
    XSelectInput(display, window, ButtonPressMask | KeyPressMask | ExposureMask);

    /* show up window */
    XMapRaised(display, window);
    
    /* event loop */
    done = 0;
    while (done == 0) {
        XNextEvent(display, &ev);
        if (ev.type == Expose) {
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