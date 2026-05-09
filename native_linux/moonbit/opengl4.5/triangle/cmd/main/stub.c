#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <GL/gl.h>
#include <GL/glx.h>
#include <stddef.h>
#include <stdbool.h>
#include <unistd.h>

#define WINDOW_WIDTH  640
#define WINDOW_HEIGHT 480

#ifndef APIENTRYP
#define APIENTRYP *
#endif
#define GL_ARRAY_BUFFER    0x8892
#define GL_STATIC_DRAW     0x88E4
#define GL_VERTEX_SHADER   0x8B31
#define GL_FRAGMENT_SHADER 0x8B30

#ifndef GLX_CONTEXT_MAJOR_VERSION_ARB
#define GLX_CONTEXT_MAJOR_VERSION_ARB    0x2091
#define GLX_CONTEXT_MINOR_VERSION_ARB    0x2092
#define GLX_CONTEXT_PROFILE_MASK_ARB     0x9126
#define GLX_CONTEXT_CORE_PROFILE_BIT_ARB 0x00000001
#endif

typedef ptrdiff_t GLsizeiptr;
typedef char GLchar;
typedef void   (APIENTRYP PFNGLGENBUFFERSPROC)(GLsizei, GLuint *);
typedef void   (APIENTRYP PFNGLBINDBUFFERPROC)(GLenum, GLuint);
typedef void   (APIENTRYP PFNGLBUFFERDATAPROC)(GLenum, GLsizeiptr, const void *, GLenum);
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC)(GLenum);
typedef void   (APIENTRYP PFNGLSHADERSOURCEPROC)(GLuint, GLsizei, const GLchar *const *, const GLint *);
typedef void   (APIENTRYP PFNGLCOMPILESHADERPROC)(GLuint);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC)(void);
typedef void   (APIENTRYP PFNGLATTACHSHADERPROC)(GLuint, GLuint);
typedef void   (APIENTRYP PFNGLLINKPROGRAMPROC)(GLuint);
typedef void   (APIENTRYP PFNGLUSEPROGRAMPROC)(GLuint);
typedef GLint  (APIENTRYP PFNGLGETATTRIBLOCATIONPROC)(GLuint, const GLchar *);
typedef void   (APIENTRYP PFNGLENABLEVERTEXATTRIBARRAYPROC)(GLuint);
typedef void   (APIENTRYP PFNGLVERTEXATTRIBPOINTERPROC)(GLuint, GLint, GLenum, GLboolean, GLsizei, const void *);
typedef void   (APIENTRYP PFNGLGENVERTEXARRAYSPROC)(GLsizei, GLuint *);
typedef void   (APIENTRYP PFNGLBINDVERTEXARRAYPROC)(GLuint);
typedef GLXContext (APIENTRYP PFNGLXCREATECONTEXTATTRIBSARBPROC)(Display *, GLXFBConfig, GLXContext, Bool, const int *);

static PFNGLGENBUFFERSPROC              s_glGenBuffers;
static PFNGLBINDBUFFERPROC              s_glBindBuffer;
static PFNGLBUFFERDATAPROC              s_glBufferData;
static PFNGLCREATESHADERPROC            s_glCreateShader;
static PFNGLSHADERSOURCEPROC            s_glShaderSource;
static PFNGLCOMPILESHADERPROC           s_glCompileShader;
static PFNGLCREATEPROGRAMPROC           s_glCreateProgram;
static PFNGLATTACHSHADERPROC            s_glAttachShader;
static PFNGLLINKPROGRAMPROC             s_glLinkProgram;
static PFNGLUSEPROGRAMPROC              s_glUseProgram;
static PFNGLGETATTRIBLOCATIONPROC       s_glGetAttribLocation;
static PFNGLENABLEVERTEXATTRIBARRAYPROC s_glEnableVertexAttribArray;
static PFNGLVERTEXATTRIBPOINTERPROC     s_glVertexAttribPointer;
static PFNGLGENVERTEXARRAYSPROC         s_glGenVertexArrays;
static PFNGLBINDVERTEXARRAYPROC         s_glBindVertexArray;
static PFNGLXCREATECONTEXTATTRIBSARBPROC s_glXCreateContextAttribsARB;

static const GLchar *vertSrc =
    "#version 450 core\n"
    "layout(location = 0) in vec3 position;\n"
    "layout(location = 1) in vec3 color;\n"
    "out vec4 vColor;\n"
    "void main() { vColor = vec4(color,1.0); gl_Position = vec4(position,1.0); }\n";
static const GLchar *fragSrc =
    "#version 450 core\n"
    "in  vec4 vColor;\n"
    "out vec4 outColor;\n"
    "void main() { outColor = vColor; }\n";

static GLuint s_vbo[2], s_vao, s_prog;
static GLint  s_posAttrib, s_colAttrib;

static void init_funcs(void) {
#define GET(t,n) s_##n = (t)glXGetProcAddressARB((const GLubyte *)#n)
    GET(PFNGLGENBUFFERSPROC,              glGenBuffers);
    GET(PFNGLBINDBUFFERPROC,              glBindBuffer);
    GET(PFNGLBUFFERDATAPROC,              glBufferData);
    GET(PFNGLCREATESHADERPROC,            glCreateShader);
    GET(PFNGLSHADERSOURCEPROC,            glShaderSource);
    GET(PFNGLCOMPILESHADERPROC,           glCompileShader);
    GET(PFNGLCREATEPROGRAMPROC,           glCreateProgram);
    GET(PFNGLATTACHSHADERPROC,            glAttachShader);
    GET(PFNGLLINKPROGRAMPROC,             glLinkProgram);
    GET(PFNGLUSEPROGRAMPROC,              glUseProgram);
    GET(PFNGLGETATTRIBLOCATIONPROC,       glGetAttribLocation);
    GET(PFNGLENABLEVERTEXATTRIBARRAYPROC, glEnableVertexAttribArray);
    GET(PFNGLVERTEXATTRIBPOINTERPROC,     glVertexAttribPointer);
    GET(PFNGLGENVERTEXARRAYSPROC,         glGenVertexArrays);
    GET(PFNGLBINDVERTEXARRAYPROC,         glBindVertexArray);
#undef GET
}

static void init_shader(void) {
    static const GLfloat verts[]  = { 0.0f, 0.5f,0.0f,  0.5f,-0.5f,0.0f, -0.5f,-0.5f,0.0f };
    static const GLfloat colors[] = { 1.0f,0.0f,0.0f,   0.0f,1.0f,0.0f,   0.0f,0.0f,1.0f  };

    s_glGenVertexArrays(1, &s_vao);
    s_glBindVertexArray(s_vao);
    s_glGenBuffers(2, s_vbo);

    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[0]);
    s_glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[1]);
    s_glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);

    GLuint vs = s_glCreateShader(GL_VERTEX_SHADER);
    s_glShaderSource(vs, 1, &vertSrc, NULL); s_glCompileShader(vs);
    GLuint fs = s_glCreateShader(GL_FRAGMENT_SHADER);
    s_glShaderSource(fs, 1, &fragSrc, NULL); s_glCompileShader(fs);

    s_prog = s_glCreateProgram();
    s_glAttachShader(s_prog, vs); s_glAttachShader(s_prog, fs);
    s_glLinkProgram(s_prog); s_glUseProgram(s_prog);

    s_posAttrib = s_glGetAttribLocation(s_prog, "position");
    s_glEnableVertexAttribArray(s_posAttrib);
    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[0]);
    s_glVertexAttribPointer(s_posAttrib, 3, GL_FLOAT, GL_FALSE, 0, (const void *)0);

    s_colAttrib = s_glGetAttribLocation(s_prog, "color");
    s_glEnableVertexAttribArray(s_colAttrib);
    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[1]);
    s_glVertexAttribPointer(s_colAttrib, 3, GL_FLOAT, GL_FALSE, 0, (const void *)0);

    s_glBindVertexArray(0);
}

static void render(void) {
    s_glUseProgram(s_prog);
    s_glBindVertexArray(s_vao);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    s_glBindVertexArray(0);
}

void run_opengl(void) {
    Display *display = XOpenDisplay(NULL);
    int screenId = DefaultScreen(display);

    GLint glxAttribs[] = {
        GLX_X_RENDERABLE, True, GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT,
        GLX_RENDER_TYPE,  GLX_RGBA_BIT, GLX_X_VISUAL_TYPE, GLX_TRUE_COLOR,
        GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8, GLX_BLUE_SIZE, 8, GLX_ALPHA_SIZE, 8,
        GLX_DEPTH_SIZE, 24, GLX_STENCIL_SIZE, 8, GLX_DOUBLEBUFFER, True, None
    };
    int fbcount;
    GLXFBConfig *fbc = glXChooseFBConfig(display, screenId, glxAttribs, &fbcount);
    int best = -1, best_samp = -1;
    for (int i = 0; i < fbcount; i++) {
        XVisualInfo *vi = glXGetVisualFromFBConfig(display, fbc[i]);
        if (vi) {
            int sb, s;
            glXGetFBConfigAttrib(display, fbc[i], GLX_SAMPLE_BUFFERS, &sb);
            glXGetFBConfigAttrib(display, fbc[i], GLX_SAMPLES, &s);
            if (best < 0 || (sb && s > best_samp)) { best = i; best_samp = s; }
        }
        XFree(vi);
    }
    GLXFBConfig bestFbc = fbc[best]; XFree(fbc);

    XVisualInfo *visual = glXGetVisualFromFBConfig(display, bestFbc);
    XSetWindowAttributes wa;
    wa.border_pixel     = BlackPixel(display, screenId);
    wa.background_pixel = WhitePixel(display, screenId);
    wa.override_redirect = True;
    wa.colormap         = XCreateColormap(display, RootWindow(display, screenId), visual->visual, AllocNone);
    wa.event_mask       = ExposureMask;
    Window window = XCreateWindow(display, RootWindow(display, screenId),
        0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, visual->depth, InputOutput, visual->visual,
        CWBackPixel | CWColormap | CWBorderPixel | CWEventMask, &wa);

    XSetStandardProperties(display, window, "Hello, World!", NULL, None, NULL, 0, NULL);
    Atom wmDelete = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &wmDelete, 1);

    s_glXCreateContextAttribsARB = (PFNGLXCREATECONTEXTATTRIBSARBPROC)
        glXGetProcAddressARB((const GLubyte *)"glXCreateContextAttribsARB");

    int ctxAttribs[] = {
        GLX_CONTEXT_MAJOR_VERSION_ARB, 4,
        GLX_CONTEXT_MINOR_VERSION_ARB, 5,
        GLX_CONTEXT_PROFILE_MASK_ARB,  GLX_CONTEXT_CORE_PROFILE_BIT_ARB,
        None
    };
    GLXContext ctx = 0;
    if (s_glXCreateContextAttribsARB)
        ctx = s_glXCreateContextAttribsARB(display, bestFbc, 0, True, ctxAttribs);
    if (!ctx)
        ctx = glXCreateNewContext(display, bestFbc, GLX_RGBA_TYPE, 0, True);
    XSync(display, False);
    glXMakeCurrent(display, window, ctx);

    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glViewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT);
    XClearWindow(display, window);
    XMapRaised(display, window);

    init_funcs();
    init_shader();

    XEvent ev;
    for (;;) {
        while (XPending(display) > 0) {
            XNextEvent(display, &ev);
            if (ev.type == ClientMessage && ev.xclient.data.l[0] == (long)wmDelete) goto done;
            if (ev.type == DestroyNotify) goto done;
        }
        render();
        glXSwapBuffers(display, window);
        usleep(16000);
    }
done:
    glXDestroyContext(display, ctx);
    XFree(visual);
    XFreeColormap(display, wa.colormap);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
}
