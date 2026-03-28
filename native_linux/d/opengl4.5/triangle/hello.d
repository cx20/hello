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

enum int GLX_DOUBLEBUFFER                 = 5;
enum int GLX_RED_SIZE                     = 8;
enum int GLX_GREEN_SIZE                   = 9;
enum int GLX_BLUE_SIZE                    = 10;
enum int GLX_ALPHA_SIZE                   = 11;
enum int GLX_DEPTH_SIZE                   = 12;
enum int GLX_STENCIL_SIZE                 = 13;
enum int GLX_X_VISUAL_TYPE                = 0x22;
enum int GLX_TRUE_COLOR                   = 0x8002;
enum int GLX_RGBA_BIT                     = 0x00000001;
enum int GLX_WINDOW_BIT                   = 0x00000001;
enum int GLX_RENDER_TYPE                  = 0x8011;
enum int GLX_DRAWABLE_TYPE                = 0x8010;
enum int GLX_X_RENDERABLE                 = 0x8012;
enum int GLX_RGBA_TYPE                    = 0x8014;
enum int GLX_SAMPLE_BUFFERS               = 0x186A0;
enum int GLX_SAMPLES                      = 0x186A1;
enum int GLX_CONTEXT_MAJOR_VERSION_ARB    = 0x2091;
enum int GLX_CONTEXT_MINOR_VERSION_ARB    = 0x2092;
enum int GLX_CONTEXT_PROFILE_MASK_ARB     = 0x9126;
enum int GLX_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;

enum GLenum GL_COLOR_BUFFER_BIT = 0x4000;
enum GLenum GL_TRIANGLES        = 0x0004;
enum GLenum GL_FLOAT            = 0x1406;
enum GLenum GL_ARRAY_BUFFER     = 0x8892;
enum GLenum GL_STATIC_DRAW      = 0x88E4;
enum GLenum GL_VERTEX_SHADER    = 0x8B31;
enum GLenum GL_FRAGMENT_SHADER  = 0x8B30;

// Function pointer type aliases
alias PFNGLGENBUFFERSPROC              = extern(C) void   function(GLsizei, GLuint*);
alias PFNGLBINDBUFFERPROC              = extern(C) void   function(GLenum, GLuint);
alias PFNGLBUFFERDATAPROC              = extern(C) void   function(GLenum, GLsizeiptr, const(void)*, GLenum);
alias PFNGLCREATESHADERPROC            = extern(C) GLuint function(GLenum);
alias PFNGLSHADERSOURCEPROC            = extern(C) void   function(GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
alias PFNGLCOMPILESHADERPROC           = extern(C) void   function(GLuint);
alias PFNGLCREATEPROGRAMPROC           = extern(C) GLuint function();
alias PFNGLATTACHSHADERPROC            = extern(C) void   function(GLuint, GLuint);
alias PFNGLLINKPROGRAMPROC             = extern(C) void   function(GLuint);
alias PFNGLUSEPROGRAMPROC              = extern(C) void   function(GLuint);
alias PFNGLGETATTRIBLOCATIONPROC       = extern(C) GLint  function(GLuint, const(GLchar)*);
alias PFNGLENABLEVERTEXATTRIBARRAYPROC = extern(C) void   function(GLuint);
alias PFNGLVERTEXATTRIBPOINTERPROC     = extern(C) void   function(GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
alias PFNGLGENVERTEXARRAYSPROC         = extern(C) void   function(GLsizei, GLuint*);
alias PFNGLBINDVERTEXARRAYPROC         = extern(C) void   function(GLuint);
alias PFNGLXCREATECONTEXTATTRIBSARBPROC = extern(C) GLXContext function(Display*, GLXFBConfig, GLXContext, Bool, const(int)*);

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

extern(D):

enum WINDOW_WIDTH  = 640;
enum WINDOW_HEIGHT = 480;

__gshared PFNGLGENBUFFERSPROC              glGenBuffers;
__gshared PFNGLBINDBUFFERPROC              glBindBuffer;
__gshared PFNGLBUFFERDATAPROC              glBufferData;
__gshared PFNGLCREATESHADERPROC            glCreateShader;
__gshared PFNGLSHADERSOURCEPROC            glShaderSource;
__gshared PFNGLCOMPILESHADERPROC           glCompileShader;
__gshared PFNGLCREATEPROGRAMPROC           glCreateProgram;
__gshared PFNGLATTACHSHADERPROC            glAttachShader;
__gshared PFNGLLINKPROGRAMPROC             glLinkProgram;
__gshared PFNGLUSEPROGRAMPROC              glUseProgram;
__gshared PFNGLGETATTRIBLOCATIONPROC       glGetAttribLocation;
__gshared PFNGLENABLEVERTEXATTRIBARRAYPROC glEnableVertexAttribArray;
__gshared PFNGLVERTEXATTRIBPOINTERPROC     glVertexAttribPointer;
__gshared PFNGLGENVERTEXARRAYSPROC         glGenVertexArrays;
__gshared PFNGLBINDVERTEXARRAYPROC         glBindVertexArray;

__gshared GLuint vao, vboVertices, vboColors, shaderProgram;

immutable vertexSrc =
    "#version 450 core\n" ~
    "layout(location = 0) in vec3 position;\n" ~
    "layout(location = 1) in vec3 color;\n" ~
    "out vec4 vColor;\n" ~
    "void main() { vColor = vec4(color, 1.0); gl_Position = vec4(position, 1.0); }\n";

immutable fragmentSrc =
    "#version 450 core\n" ~
    "in  vec4 vColor;\n" ~
    "out vec4 outColor;\n" ~
    "void main() { outColor = vColor; }\n";

void initOpenGLFunc()
{
    glGenBuffers              = cast(PFNGLGENBUFFERSPROC)              glXGetProcAddressARB(cast(const(GLubyte)*)"glGenBuffers".ptr);
    glBindBuffer              = cast(PFNGLBINDBUFFERPROC)              glXGetProcAddressARB(cast(const(GLubyte)*)"glBindBuffer".ptr);
    glBufferData              = cast(PFNGLBUFFERDATAPROC)              glXGetProcAddressARB(cast(const(GLubyte)*)"glBufferData".ptr);
    glCreateShader            = cast(PFNGLCREATESHADERPROC)            glXGetProcAddressARB(cast(const(GLubyte)*)"glCreateShader".ptr);
    glShaderSource            = cast(PFNGLSHADERSOURCEPROC)            glXGetProcAddressARB(cast(const(GLubyte)*)"glShaderSource".ptr);
    glCompileShader           = cast(PFNGLCOMPILESHADERPROC)           glXGetProcAddressARB(cast(const(GLubyte)*)"glCompileShader".ptr);
    glCreateProgram           = cast(PFNGLCREATEPROGRAMPROC)           glXGetProcAddressARB(cast(const(GLubyte)*)"glCreateProgram".ptr);
    glAttachShader            = cast(PFNGLATTACHSHADERPROC)            glXGetProcAddressARB(cast(const(GLubyte)*)"glAttachShader".ptr);
    glLinkProgram             = cast(PFNGLLINKPROGRAMPROC)             glXGetProcAddressARB(cast(const(GLubyte)*)"glLinkProgram".ptr);
    glUseProgram              = cast(PFNGLUSEPROGRAMPROC)              glXGetProcAddressARB(cast(const(GLubyte)*)"glUseProgram".ptr);
    glGetAttribLocation       = cast(PFNGLGETATTRIBLOCATIONPROC)       glXGetProcAddressARB(cast(const(GLubyte)*)"glGetAttribLocation".ptr);
    glEnableVertexAttribArray = cast(PFNGLENABLEVERTEXATTRIBARRAYPROC) glXGetProcAddressARB(cast(const(GLubyte)*)"glEnableVertexAttribArray".ptr);
    glVertexAttribPointer     = cast(PFNGLVERTEXATTRIBPOINTERPROC)     glXGetProcAddressARB(cast(const(GLubyte)*)"glVertexAttribPointer".ptr);
    glGenVertexArrays         = cast(PFNGLGENVERTEXARRAYSPROC)         glXGetProcAddressARB(cast(const(GLubyte)*)"glGenVertexArrays".ptr);
    glBindVertexArray         = cast(PFNGLBINDVERTEXARRAYPROC)         glXGetProcAddressARB(cast(const(GLubyte)*)"glBindVertexArray".ptr);
}

void initShader()
{
    GLfloat[9] vertices = [ 0.0f, 0.5f, 0.0f,  0.5f, -0.5f, 0.0f,  -0.5f, -0.5f, 0.0f ];
    GLfloat[9] colors   = [ 1.0f, 0.0f, 0.0f,  0.0f,  1.0f, 0.0f,   0.0f,  0.0f, 1.0f ];

    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    glGenBuffers(1, &vboVertices);
    glBindBuffer(GL_ARRAY_BUFFER, vboVertices);
    glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(vertices.length * GLfloat.sizeof), vertices.ptr, GL_STATIC_DRAW);

    glGenBuffers(1, &vboColors);
    glBindBuffer(GL_ARRAY_BUFFER, vboColors);
    glBufferData(GL_ARRAY_BUFFER, cast(GLsizeiptr)(colors.length * GLfloat.sizeof), colors.ptr, GL_STATIC_DRAW);

    GLuint vs = glCreateShader(GL_VERTEX_SHADER);
    const(char)* vSrc = vertexSrc.ptr;
    glShaderSource(vs, 1, &vSrc, null);
    glCompileShader(vs);

    GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
    const(char)* fSrc = fragmentSrc.ptr;
    glShaderSource(fs, 1, &fSrc, null);
    glCompileShader(fs);

    shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vs);
    glAttachShader(shaderProgram, fs);
    glLinkProgram(shaderProgram);

    glBindVertexArray(0);
}

void initialize(int w, int h)
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glViewport(0, 0, w, h);
}

void render()
{
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(shaderProgram);

    glBindVertexArray(vao);

    GLint posAttrib = glGetAttribLocation(shaderProgram, "position".ptr);
    glEnableVertexAttribArray(cast(GLuint)posAttrib);
    glBindBuffer(GL_ARRAY_BUFFER, vboVertices);
    glVertexAttribPointer(cast(GLuint)posAttrib, 3, GL_FLOAT, cast(GLboolean)0, 0, null);

    GLint colAttrib = glGetAttribLocation(shaderProgram, "color".ptr);
    glEnableVertexAttribArray(cast(GLuint)colAttrib);
    glBindBuffer(GL_ARRAY_BUFFER, vboColors);
    glVertexAttribPointer(cast(GLuint)colAttrib, 3, GL_FLOAT, cast(GLboolean)0, 0, null);

    glDrawArrays(GL_TRIANGLES, 0, 3);

    glBindVertexArray(0);
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

    // Load glXCreateContextAttribsARB before creating the context
    auto glXCreateContextAttribsARB = cast(PFNGLXCREATECONTEXTATTRIBSARBPROC)
        glXGetProcAddressARB(cast(const(GLubyte)*)"glXCreateContextAttribsARB".ptr);

    int[7] contextAttribs = [
        GLX_CONTEXT_MAJOR_VERSION_ARB, 4,
        GLX_CONTEXT_MINOR_VERSION_ARB, 5,
        GLX_CONTEXT_PROFILE_MASK_ARB,  GLX_CONTEXT_CORE_PROFILE_BIT_ARB,
        cast(int)None
    ];

    GLXContext context;
    if (glXCreateContextAttribsARB !is null)
        context = glXCreateContextAttribsARB(display, bestFbc, null, True_, contextAttribs.ptr);
    else
        context = glXCreateNewContext(display, bestFbc, GLX_RGBA_TYPE, null, True_);

    XSync(display, 0);
    glXIsDirect(display, context);
    glXMakeCurrent(display, window, context);

    initialize(WINDOW_WIDTH, WINDOW_HEIGHT);
    XClearWindow(display, window);
    XMapRaised(display, window);

    initOpenGLFunc();
    initShader();

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
