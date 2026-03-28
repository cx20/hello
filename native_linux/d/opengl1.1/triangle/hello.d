extern(C):

alias Display    = void;
alias XID        = ulong;
alias Window     = XID;
alias Atom       = ulong;
alias Pixmap     = XID;
alias Colormap   = XID;
alias Cursor     = XID;
alias Bool       = int;
alias Status     = int;
alias GLXContext  = void*;
alias GLXFBConfig = void*;
alias GLXDrawable = XID;

alias GLenum     = uint;
alias GLboolean  = ubyte;
alias GLbitfield = uint;
alias GLint      = int;
alias GLuint     = uint;
alias GLsizei    = int;
alias GLfloat    = float;
alias GLchar     = char;
alias GLsizeiptr = ptrdiff_t;
alias GLubyte    = ubyte;

enum int   False_  = 0;
enum int   True_   = 1;
enum ulong None    = 0;

enum long  ExposureMask   = 1L << 15;
enum int   Expose         = 12;
enum int   ClientMessage  = 33;
enum int   DestroyNotify  = 17;

enum ulong CWBackPixel   = 1UL << 1;
enum ulong CWBorderPixel = 1UL << 3;
enum ulong CWColormap    = 1UL << 13;
enum ulong CWEventMask   = 1UL << 11;
enum uint  InputOutput   = 1;
enum int   AllocNone     = 0;

enum int GLX_DOUBLEBUFFER   = 5;
enum int GLX_RED_SIZE       = 8;
enum int GLX_GREEN_SIZE     = 9;
enum int GLX_BLUE_SIZE      = 10;
enum int GLX_ALPHA_SIZE     = 11;
enum int GLX_DEPTH_SIZE     = 12;
enum int GLX_STENCIL_SIZE   = 13;
enum int GLX_X_VISUAL_TYPE  = 0x22;
enum int GLX_TRUE_COLOR     = 0x8002;
enum int GLX_RGBA_BIT       = 0x00000001;
enum int GLX_WINDOW_BIT     = 0x00000001;
enum int GLX_RENDER_TYPE    = 0x8011;
enum int GLX_DRAWABLE_TYPE  = 0x8010;
enum int GLX_X_RENDERABLE   = 0x8012;
enum int GLX_RGBA_TYPE      = 0x8014;
enum int GLX_SAMPLE_BUFFERS = 0x186A0;
enum int GLX_SAMPLES        = 0x186A1;

enum GLenum GL_COLOR_BUFFER_BIT = 0x4000;
enum GLenum GL_TRIANGLES        = 0x0004;
enum GLenum GL_FLOAT            = 0x1406;

// OpenGL 1.1 vertex array constants
enum GLenum GL_VERTEX_ARRAY = 0x8074;
enum GLenum GL_COLOR_ARRAY  = 0x8076;

struct XSizeHints {
    long flags;
    int x, y, width, height;
    int min_width, min_height;
    int max_width, max_height;
    int width_inc, height_inc;
    struct AR { int x, y; }
    AR min_aspect, max_aspect;
    int base_width, base_height;
    int win_gravity;
}

struct XVisualInfo {
    void*  visual;
    ulong  visualid;
    int    screen;
    int    depth;
    int    class_;
    ulong  red_mask;
    ulong  green_mask;
    ulong  blue_mask;
    int    colormap_size;
    int    bits_per_rgb;
}

struct XSetWindowAttributes {
    ulong background_pixmap;
    ulong background_pixel;
    ulong border_pixmap;
    ulong border_pixel;
    int   bit_gravity;
    int   win_gravity;
    int   backing_store;
    ulong backing_planes;
    ulong backing_pixel;
    Bool  save_under;
    long  event_mask;
    long  do_not_propagate_mask;
    Bool  override_redirect;
    ulong colormap;
    ulong cursor;
}

struct XClientMessageEvent {
    int      type;
    ulong    serial;
    Bool     send_event;
    Display* display;
    Window   window;
    Atom     message_type;
    int      format;
    union Data { byte[20] b; short[10] s; long[5] l; }
    Data data;
}

struct XExposeEvent {
    int      type;
    ulong    serial;
    Bool     send_event;
    Display* display;
    Window   window;
    int x, y, width, height, count;
}

struct XDestroyWindowEvent {
    int      type;
    ulong    serial;
    Bool     send_event;
    Display* display;
    Window   event;
    Window   window;
}

union XEvent {
    int                 type;
    XExposeEvent        xexpose;
    XClientMessageEvent xclient;
    XDestroyWindowEvent xdestroywindow;
    byte[192]           pad;
}

struct XWindowAttributes { byte[232] pad; }

Display* XOpenDisplay(const(char)*);
int      XCloseDisplay(Display*);
int      XDefaultScreen(Display*);
ulong    XBlackPixel(Display*, int);
ulong    XWhitePixel(Display*, int);
Window   XDefaultRootWindow(Display*);
Colormap XCreateColormap(Display*, Window, void*, int);
Window   XCreateWindow(Display*, Window, int, int, uint, uint, uint, int, uint, void*, ulong, XSetWindowAttributes*);
int      XSetStandardProperties(Display*, Window, const(char)*, const(char)*, Pixmap, char**, int, XSizeHints*);
Atom     XInternAtom(Display*, const(char)*, Bool);
Status   XSetWMProtocols(Display*, Window, Atom*, int);
int      XClearWindow(Display*, Window);
int      XMapRaised(Display*, Window);
int      XPending(Display*);
int      XNextEvent(Display*, XEvent*);
int      XGetWindowAttributes(Display*, Window, XWindowAttributes*);
int      XFree(void*);
int      XFreeColormap(Display*, Colormap);
int      XDestroyWindow(Display*, Window);
void     XSync(Display*, Bool);

Bool         glXQueryVersion(Display*, int*, int*);
GLXFBConfig* glXChooseFBConfig(Display*, int, const(int)*, int*);
int          glXGetFBConfigAttrib(Display*, GLXFBConfig, int, int*);
XVisualInfo* glXGetVisualFromFBConfig(Display*, GLXFBConfig);
GLXContext   glXCreateNewContext(Display*, GLXFBConfig, int, GLXContext, Bool);
Bool         glXIsDirect(Display*, GLXContext);
Bool         glXMakeCurrent(Display*, GLXDrawable, GLXContext);
void         glXSwapBuffers(Display*, GLXDrawable);
void         glXDestroyContext(Display*, GLXContext);
void*        glXGetProcAddressARB(const(GLubyte)*);

void glClearColor(GLfloat, GLfloat, GLfloat, GLfloat);
void glViewport(GLint, GLint, GLsizei, GLsizei);
void glClear(GLbitfield);
void glDrawArrays(GLenum, GLint, GLsizei);

// OpenGL 1.1 vertex array functions
void glEnableClientState(GLenum);
void glVertexPointer(GLint, GLenum, GLsizei, const(void)*);
void glColorPointer(GLint, GLenum, GLsizei, const(void)*);

extern(D):

enum WINDOW_WIDTH  = 640;
enum WINDOW_HEIGHT = 480;

void initialize(int w, int h)
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glViewport(0, 0, w, h);
}

void render()
{
    GLfloat[9] vertices = [ 0.0f, 0.5f, 0.0f,  0.5f, -0.5f, 0.0f,  -0.5f, -0.5f, 0.0f ];
    GLfloat[9] colors   = [ 1.0f, 0.0f, 0.0f,  0.0f,  1.0f, 0.0f,   0.0f,  0.0f, 1.0f ];
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    glVertexPointer(3, GL_FLOAT, 0, vertices.ptr);
    glColorPointer(3, GL_FLOAT, 0, colors.ptr);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

void main()
{
    Display* display = XOpenDisplay(null);
    int screenId = XDefaultScreen(display);

    int[23] glxAttribs = [
        GLX_X_RENDERABLE,  True_,
        GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT,
        GLX_RENDER_TYPE,   GLX_RGBA_BIT,
        GLX_X_VISUAL_TYPE, GLX_TRUE_COLOR,
        GLX_RED_SIZE,      8,
        GLX_GREEN_SIZE,    8,
        GLX_BLUE_SIZE,     8,
        GLX_ALPHA_SIZE,    8,
        GLX_DEPTH_SIZE,    24,
        GLX_STENCIL_SIZE,  8,
        GLX_DOUBLEBUFFER,  True_,
        cast(int)None
    ];

    int fbcount;
    GLXFBConfig* fbc = glXChooseFBConfig(display, screenId, glxAttribs.ptr, &fbcount);

    int best_fbc = -1, best_num_samp = -1, worst_fbc = -1, worst_num_samp = 999;
    foreach (i; 0 .. fbcount) {
        XVisualInfo* vi = glXGetVisualFromFBConfig(display, fbc[i]);
        if (vi !is null) {
            int samp_buf, samples;
            glXGetFBConfigAttrib(display, fbc[i], GLX_SAMPLE_BUFFERS, &samp_buf);
            glXGetFBConfigAttrib(display, fbc[i], GLX_SAMPLES,        &samples);
            if (best_fbc < 0 || (samp_buf && samples > best_num_samp)) {
                best_fbc = i; best_num_samp = samples;
            }
            if (worst_fbc < 0 || !samp_buf || samples < worst_num_samp) {
                worst_fbc = i; worst_num_samp = samples;
            }
        }
        XFree(vi);
    }
    GLXFBConfig bestFbc = fbc[best_fbc];
    XFree(fbc);

    XVisualInfo* visual = glXGetVisualFromFBConfig(display, bestFbc);

    XSetWindowAttributes windowAttribs;
    windowAttribs.border_pixel      = XBlackPixel(display, screenId);
    windowAttribs.background_pixel  = XWhitePixel(display, screenId);
    windowAttribs.override_redirect = True_;
    windowAttribs.colormap = XCreateColormap(display,
        XDefaultRootWindow(display), visual.visual, AllocNone);
    windowAttribs.event_mask = ExposureMask;

    Window window = XCreateWindow(display, XDefaultRootWindow(display),
        0, 0, WINDOW_WIDTH, WINDOW_HEIGHT,
        0, visual.depth, InputOutput, visual.visual,
        CWBackPixel | CWColormap | CWBorderPixel | CWEventMask,
        &windowAttribs);

    XSetStandardProperties(display, window, "Hello, World!".ptr, null, None, null, 0, null);

    Atom atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW".ptr, 0);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    GLXContext context = glXCreateNewContext(display, bestFbc, GLX_RGBA_TYPE, null, True_);
    XSync(display, 0);
    glXIsDirect(display, context);
    glXMakeCurrent(display, window, context);

    initialize(WINDOW_WIDTH, WINDOW_HEIGHT);
    XClearWindow(display, window);
    XMapRaised(display, window);

    bool done = false;
    while (!done) {
        if (XPending(display) > 0) {
            XEvent ev;
            XNextEvent(display, &ev);
            if (ev.type == Expose) {
                XWindowAttributes attribs;
                XGetWindowAttributes(display, window, &attribs);
            }
            if (ev.type == ClientMessage) {
                if (ev.xclient.data.l[0] == cast(long)atomWmDeleteWindow)
                    done = true;
            } else if (ev.type == DestroyNotify) {
                done = true;
            }
        }
        render();
        glXSwapBuffers(display, window);
    }

    glXDestroyContext(display, context);
    XFree(visual);
    XFreeColormap(display, windowAttribs.colormap);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
}
