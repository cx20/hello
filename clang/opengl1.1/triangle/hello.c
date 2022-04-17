#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <GL/gl.h>
#include <GL/glx.h>

#include <stdbool.h>
#include <unistd.h>

#define WINDOW_WIDTH    640
#define WINDOW_HEIGHT   480

extern bool Initialize(int w, int h);
extern bool Update(float deltaTime);
extern void Render();
extern void Shutdown();

typedef GLXContext (*glXCreateContextAttribsARBProc)(Display*, GLXFBConfig, GLXContext, Bool, const int*);

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

void Render() {
    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);

    GLfloat colors[] = {
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    };
    GLfloat vertices[] = {
         0.0f,  0.5f,
         0.5f, -0.5f,
        -0.5f, -0.5f,
    };

    glColorPointer(3, GL_FLOAT, 0, colors);
    glVertexPointer(2, GL_FLOAT, 0, vertices);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
}
