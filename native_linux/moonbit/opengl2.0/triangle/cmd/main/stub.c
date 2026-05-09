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
#define GL_ARRAY_BUFFER  0x8892
#define GL_STATIC_DRAW   0x88E4
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30

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

static const GLchar *vertSrc =
    "#version 110\n"
    "attribute vec3 position;\n"
    "attribute vec3 color;\n"
    "varying   vec4 vColor;\n"
    "void main() { vColor = vec4(color,1.0); gl_Position = vec4(position,1.0); }\n";
static const GLchar *fragSrc =
    "#version 110\n"
    "varying vec4 vColor;\n"
    "void main() { gl_FragColor = vColor; }\n";

static GLuint s_vbo[2];
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
#undef GET
}

static void init_shader(void) {
    static const GLfloat verts[]  = { 0.0f, 0.5f,0.0f,  0.5f,-0.5f,0.0f, -0.5f,-0.5f,0.0f };
    static const GLfloat colors[] = { 1.0f,0.0f,0.0f,   0.0f,1.0f,0.0f,   0.0f,0.0f,1.0f  };

    s_glGenBuffers(2, s_vbo);
    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[0]);
    s_glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[1]);
    s_glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);

    GLuint vs = s_glCreateShader(GL_VERTEX_SHADER);
    s_glShaderSource(vs, 1, &vertSrc, NULL); s_glCompileShader(vs);
    GLuint fs = s_glCreateShader(GL_FRAGMENT_SHADER);
    s_glShaderSource(fs, 1, &fragSrc, NULL); s_glCompileShader(fs);

    GLuint prog = s_glCreateProgram();
    s_glAttachShader(prog, vs); s_glAttachShader(prog, fs);
    s_glLinkProgram(prog); s_glUseProgram(prog);

    s_posAttrib = s_glGetAttribLocation(prog, "position");
    s_glEnableVertexAttribArray(s_posAttrib);
    s_colAttrib = s_glGetAttribLocation(prog, "color");
    s_glEnableVertexAttribArray(s_colAttrib);
}

static void render(void) {
    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[0]);
    s_glVertexAttribPointer(s_posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    s_glBindBuffer(GL_ARRAY_BUFFER, s_vbo[1]);
    s_glVertexAttribPointer(s_colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLES, 0, 3);
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

    GLXContext ctx = glXCreateNewContext(display, bestFbc, GLX_RGBA_TYPE, 0, True);
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
