import core.stdc.stdlib : exit;
import core.stdc.string : strlen;

extern(C):

alias Display = void;
alias Window = uint;
alias GC = void*;
alias Atom = uint;
alias Pixmap = uint;
alias Cursor = uint;
alias Colormap = uint;
alias VisualID = uint;
alias Time = uint;
alias KeySym = uint;
alias Status = int;
alias Bool = int;

enum None = 0;
enum PPosition = 4;
enum PSize = 8;
enum ButtonPressMask = 4;
enum KeyPressMask = 1;
enum ExposureMask = 32768;
enum Expose = 12;
enum ClientMessage = 33;
enum DestroyNotify = 17;

struct XSizeHints {
    long flags;
    int x, y, width, height;
    int min_width, min_height;
    int max_width, max_height;
    int width_inc, height_inc;
    struct AspectRatio { int x, y; }
    AspectRatio min_aspect, max_aspect;
    int base_width, base_height;
    int win_gravity;
}

struct XClientMessageEvent {
    int type;
    uint serial;
    Bool send_event;
    Display* display;
    Window window;
    Atom message_type;
    int format;
    union Data {
        byte[20]  b;
        short[10] s;
        long[5]   l;
    }
    Data data;
}

struct XExposeEvent {
    int type;
    uint serial;
    Bool send_event;
    Display* display;
    Window window;
    int x, y;
    int width, height;
    int count;
}

struct XDestroyWindowEvent {
    int type;
    uint serial;
    Bool send_event;
    Display* display;
    Window event;
    Window window;
}

union XEvent {
    int type;
    XExposeEvent xexpose;
    XClientMessageEvent xclient;
    XDestroyWindowEvent xdestroywindow;
    byte[192] pad;
}

Display* XOpenDisplay(const(char)* display_name);
int       XCloseDisplay(Display* display);
int       XDefaultScreen(Display* display);
uint      XBlackPixel(Display* display, int screen_number);
uint      XWhitePixel(Display* display, int screen_number);
Window    XDefaultRootWindow(Display* display);
Window    XCreateSimpleWindow(Display* display, Window parent,
              int x, int y, uint width, uint height,
              uint border_width, uint border, uint background);
int       XSetStandardProperties(Display* display, Window w,
              const(char)* window_name, const(char)* icon_name,
              Pixmap icon_pixmap, char** argv, int argc, XSizeHints* hints);
Atom      XInternAtom(Display* display, const(char)* atom_name, Bool only_if_exists);
Status    XSetWMProtocols(Display* display, Window w, Atom* protocols, int count);
GC        XCreateGC(Display* display, Window d, uint valuemask, void* values);
int       XSetBackground(Display* display, GC gc, uint background);
int       XSetForeground(Display* display, GC gc, uint foreground);
int       XSelectInput(Display* display, Window w, long event_mask);
int       XMapRaised(Display* display, Window w);
int       XNextEvent(Display* display, XEvent* event_return);
int       XDrawImageString(Display* display, Window d, GC gc,
              int x, int y, const(char)* string, int length);
int       XFreeGC(Display* display, GC gc);
int       XDestroyWindow(Display* display, Window w);

extern(D):

int main(char[][] args)
{
    char* helloTitle   = cast(char*) "Hello, World!";
    char* helloMessage = cast(char*) "Hello, X11 GUI World!";

    Display* display = XOpenDisplay("");
    int screen = XDefaultScreen(display);

    uint foreground = XBlackPixel(display, screen);
    uint background = XWhitePixel(display, screen);

    XSizeHints hint;
    hint.x      = 0;
    hint.y      = 0;
    hint.width  = 640;
    hint.height = 480;
    hint.flags  = PPosition | PSize;

    Window window = XCreateSimpleWindow(
        display, XDefaultRootWindow(display),
        hint.x, hint.y, hint.width, hint.height,
        5, foreground, background);

    char*[] argv = new char*[args.length];
    foreach (i, ref a; args) argv[i] = a.ptr;
    XSetStandardProperties(display, window, helloTitle, helloTitle,
        None, argv.ptr, cast(int) args.length, &hint);

    Atom atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", 0);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    GC gc = XCreateGC(display, window, 0, null);
    XSetBackground(display, gc, background);
    XSetForeground(display, gc, foreground);

    XSelectInput(display, window, ButtonPressMask | KeyPressMask | ExposureMask);
    XMapRaised(display, window);

    bool done = false;
    while (!done)
    {
        XEvent ev;
        XNextEvent(display, &ev);
        if (ev.type == Expose)
        {
            XDrawImageString(display, window, gc, 5, 20,
                helloMessage, cast(int) strlen(helloMessage));
        }
        else if (ev.type == ClientMessage)
        {
            if (ev.xclient.data.l[0] == atomWmDeleteWindow)
                done = true;
        }
        else if (ev.type == DestroyNotify)
        {
            done = true;
        }
    }

    XFreeGC(display, gc);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
    return 0;
}
