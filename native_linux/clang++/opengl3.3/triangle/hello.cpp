#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <GL/gl.h>
#include <GL/glx.h>

#include <unistd.h>

#define WINDOW_WIDTH    640
#define WINDOW_HEIGHT   480

#ifndef APIENTRY
#define APIENTRY
#endif

#ifndef APIENTRYP
#define APIENTRYP APIENTRY *
#endif

#define GL_ARRAY_BUFFER                   0x8892
#define GL_STATIC_DRAW                    0x88E4
#define GL_FRAGMENT_SHADER                0x8B30
#define GL_VERTEX_SHADER                  0x8B31

typedef ptrdiff_t GLsizeiptr;
typedef char GLchar;

typedef void (APIENTRYP PFNGLGENBUFFERSPROC) (GLsizei n, GLuint *buffers);
typedef void (APIENTRYP PFNGLBINDBUFFERPROC) (GLenum target, GLuint buffer);
typedef void (APIENTRYP PFNGLBUFFERDATAPROC) (GLenum target, GLsizeiptr size, const void *data, GLenum usage);
typedef GLuint (APIENTRYP PFNGLCREATESHADERPROC) (GLenum type);
typedef void (APIENTRYP PFNGLSHADERSOURCEPROC) (GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
typedef void (APIENTRYP PFNGLCOMPILESHADERPROC) (GLuint shader);
typedef GLuint (APIENTRYP PFNGLCREATEPROGRAMPROC) (void);
typedef void (APIENTRYP PFNGLATTACHSHADERPROC) (GLuint program, GLuint shader);
typedef void (APIENTRYP PFNGLLINKPROGRAMPROC) (GLuint program);
typedef void (APIENTRYP PFNGLUSEPROGRAMPROC) (GLuint program);
typedef GLint (APIENTRYP PFNGLGETATTRIBLOCATIONPROC) (GLuint program, const GLchar *name);
typedef void (APIENTRYP PFNGLENABLEVERTEXATTRIBARRAYPROC) (GLuint index);
typedef void (APIENTRYP PFNGLVERTEXATTRIBPOINTERPROC) (GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);

PFNGLGENBUFFERSPROC               glGenBuffers;
PFNGLBINDBUFFERPROC               glBindBuffer;
PFNGLBUFFERDATAPROC               glBufferData;
PFNGLCREATESHADERPROC             glCreateShader;
PFNGLSHADERSOURCEPROC             glShaderSource;
PFNGLCOMPILESHADERPROC            glCompileShader;
PFNGLCREATEPROGRAMPROC            glCreateProgram;
PFNGLATTACHSHADERPROC             glAttachShader;
PFNGLLINKPROGRAMPROC              glLinkProgram;
PFNGLUSEPROGRAMPROC               glUseProgram;
PFNGLGETATTRIBLOCATIONPROC        glGetAttribLocation;
PFNGLENABLEVERTEXATTRIBARRAYPROC  glEnableVertexAttribArray;
PFNGLVERTEXATTRIBPOINTERPROC      glVertexAttribPointer;

extern bool Initialize(int w, int h);
extern void InitOpenGLFunc();
extern void InitShader();
extern bool Update(float deltaTime);
extern void Render();
extern void Shutdown();

// Shader sources
const GLchar* vertexSource =
    "#version 330 core                            \n"
    "layout(location = 0) in  vec3 position;      \n"
    "layout(location = 1) in  vec3 color;         \n"
    "out vec4 vColor;                             \n"
    "void main()                                  \n"
    "{                                            \n"
    "  vColor = vec4(color, 1.0);                 \n"
    "  gl_Position = vec4(position, 1.0);         \n"
    "}                                            \n";
const GLchar* fragmentSource =
    "#version 330 core                            \n"
    "precision mediump float;                     \n"
    "in  vec4 vColor;                             \n"
    "out vec4 outColor;                           \n"
    "void main()                                  \n"
    "{                                            \n"
    "  outColor = vColor;                         \n"
    "}                                            \n";

GLuint vbo[2];
GLint posAttrib;
GLint colAttrib;

int main(int argc, char** argv) {
    Display* display;
    Window window;
    Screen* screen;
    int screenId;
    XEvent ev;

    display = XOpenDisplay(NULL);
    screen = DefaultScreenOfDisplay(display);
    screenId = DefaultScreen(display);
    
    GLint majorGLX, minorGLX = 0;
    glXQueryVersion(display, &majorGLX, &minorGLX);

    GLint glxAttribs[] = {
        GLX_X_RENDERABLE    , True,
        GLX_DRAWABLE_TYPE   , GLX_WINDOW_BIT,
        GLX_RENDER_TYPE     , GLX_RGBA_BIT,
        GLX_X_VISUAL_TYPE   , GLX_TRUE_COLOR,
        GLX_RED_SIZE        , 8,
        GLX_GREEN_SIZE      , 8,
        GLX_BLUE_SIZE       , 8,
        GLX_ALPHA_SIZE      , 8,
        GLX_DEPTH_SIZE      , 24,
        GLX_STENCIL_SIZE    , 8,
        GLX_DOUBLEBUFFER    , True,
        None
    };
    
    int fbcount;
    GLXFBConfig* fbc = glXChooseFBConfig(display, screenId, glxAttribs, &fbcount);

    int best_fbc = -1, worst_fbc = -1, best_num_samp = -1, worst_num_samp = 999;
    for (int i = 0; i < fbcount; ++i) {
        XVisualInfo *vi = glXGetVisualFromFBConfig( display, fbc[i] );
        if ( vi != 0) {
            int samp_buf, samples;
            glXGetFBConfigAttrib( display, fbc[i], GLX_SAMPLE_BUFFERS, &samp_buf );
            glXGetFBConfigAttrib( display, fbc[i], GLX_SAMPLES       , &samples  );

            if ( best_fbc < 0 || (samp_buf && samples > best_num_samp) ) {
                best_fbc = i;
                best_num_samp = samples;
            }
            if ( worst_fbc < 0 || !samp_buf || samples < worst_num_samp )
                worst_fbc = i;
            worst_num_samp = samples;
        }
        XFree( vi );
    }
    GLXFBConfig bestFbc = fbc[ best_fbc ];
    XFree( fbc );

    XVisualInfo* visual = glXGetVisualFromFBConfig( display, bestFbc );

    XSetWindowAttributes windowAttribs;
    windowAttribs.border_pixel = BlackPixel(display, screenId);
    windowAttribs.background_pixel = WhitePixel(display, screenId);
    windowAttribs.override_redirect = True;
    windowAttribs.colormap = XCreateColormap(display, RootWindow(display, screenId), visual->visual, AllocNone);
    windowAttribs.event_mask = ExposureMask;
    window = XCreateWindow(
        display,
        RootWindow(display, screenId),
        0,
        0,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        0,
        visual->depth,
        InputOutput,
        visual->visual,
        CWBackPixel | CWColormap | CWBorderPixel | CWEventMask,
        &windowAttribs
    );

    XSetStandardProperties(display, window, "Hello, World!", NULL, None, argv, argc, NULL);

    Atom atomWmDeleteWindow = XInternAtom(display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(display, window, &atomWmDeleteWindow, 1);

    GLXContext context = 0;

    context = glXCreateNewContext( display, bestFbc, GLX_RGBA_TYPE, 0, True );
    XSync( display, False );

    glXIsDirect (display, context);
    glXMakeCurrent(display, window, context);

    Initialize(WINDOW_WIDTH, WINDOW_HEIGHT);

    XClearWindow(display, window);
    XMapRaised(display, window);

    InitOpenGLFunc();
    
    InitShader();
    
    while (true) {
        if (XPending(display) > 0) {
            XNextEvent(display, &ev);
            if (ev.type == Expose) {
                XWindowAttributes attribs;
                XGetWindowAttributes(display, window, &attribs);
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

        Render();

        glXSwapBuffers(display, window);

        usleep((unsigned int)(1/60));
    }

    glXDestroyContext(display, context);

    XFree(visual);
    XFreeColormap(display, windowAttribs.colormap);
    XDestroyWindow(display, window);
    XCloseDisplay(display);
    return 0;
}

bool Initialize(int w, int h) {
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glViewport(0, 0, w, h);
    return true;
}

void InitOpenGLFunc()
{
    glGenBuffers              = (PFNGLGENBUFFERSPROC)              glXGetProcAddressARB((const GLubyte *)"glGenBuffers");
    glBindBuffer              = (PFNGLBINDBUFFERPROC)              glXGetProcAddressARB((const GLubyte *)"glBindBuffer");
    glBufferData              = (PFNGLBUFFERDATAPROC)              glXGetProcAddressARB((const GLubyte *)"glBufferData");
    glCreateShader            = (PFNGLCREATESHADERPROC)            glXGetProcAddressARB((const GLubyte *)"glCreateShader");
    glShaderSource            = (PFNGLSHADERSOURCEPROC)            glXGetProcAddressARB((const GLubyte *)"glShaderSource");
    glCompileShader           = (PFNGLCOMPILESHADERPROC)           glXGetProcAddressARB((const GLubyte *)"glCompileShader");
    glCreateProgram           = (PFNGLCREATEPROGRAMPROC)           glXGetProcAddressARB((const GLubyte *)"glCreateProgram");
    glAttachShader            = (PFNGLATTACHSHADERPROC)            glXGetProcAddressARB((const GLubyte *)"glAttachShader");
    glLinkProgram             = (PFNGLLINKPROGRAMPROC)             glXGetProcAddressARB((const GLubyte *)"glLinkProgram");
    glUseProgram              = (PFNGLUSEPROGRAMPROC)              glXGetProcAddressARB((const GLubyte *)"glUseProgram");
    glGetAttribLocation       = (PFNGLGETATTRIBLOCATIONPROC)       glXGetProcAddressARB((const GLubyte *)"glGetAttribLocation");
    glEnableVertexAttribArray = (PFNGLENABLEVERTEXATTRIBARRAYPROC) glXGetProcAddressARB((const GLubyte *)"glEnableVertexAttribArray");
    glVertexAttribPointer     = (PFNGLVERTEXATTRIBPOINTERPROC)     glXGetProcAddressARB((const GLubyte *)"glVertexAttribPointer");
}

void InitShader()
{
    glGenBuffers(2, vbo);

    GLfloat vertices[] = {
          0.0f,  0.5f, 0.0f,
          0.5f, -0.5f, 0.0f,
         -0.5f, -0.5f, 0.0f
    };

    GLfloat colors[] = {
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    };

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW);

    // Create and compile the vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexSource, nullptr);
    glCompileShader(vertexShader);

    // Create and compile the fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentSource, nullptr);
    glCompileShader(fragmentShader);

    // Link the vertex and fragment shader into a shader program
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glUseProgram(shaderProgram);
    
    // Specify the layout of the vertex data
    posAttrib = glGetAttribLocation(shaderProgram, "position");
    glEnableVertexAttribArray(posAttrib);

    colAttrib = glGetAttribLocation(shaderProgram, "color");
    glEnableVertexAttribArray(colAttrib);
}

void Render() {
    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glVertexAttribPointer(posAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 0, 0);
    
    glClear(GL_COLOR_BUFFER_BIT);

    // Draw a triangle from the 3 vertices
    glDrawArrays(GL_TRIANGLES, 0, 3);
}
