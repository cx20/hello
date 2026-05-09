#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <GL/gl.h>
#include <GL/glx.h>
#include <stdbool.h>
#include <unistd.h>

#define WINDOW_WIDTH  640
#define WINDOW_HEIGHT 480

static void render(void) {
    glClear(GL_COLOR_BUFFER_BIT);
    glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f);   glVertex2f( 0.0f,  0.50f);
        glColor3f(0.0f, 1.0f, 0.0f);   glVertex2f( 0.5f, -0.50f);
        glColor3f(0.0f, 0.0f, 1.0f);   glVertex2f(-0.5f, -0.50f);
    glEnd();
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
    GLXFBConfig bestFbc = fbc[best];
    XFree(fbc);

    XVisualInfo *visual = glXGetVisualFromFBConfig(display, bestFbc);
    XSetWindowAttributes wa;
    wa.border_pixel    = BlackPixel(display, screenId);
    wa.background_pixel= WhitePixel(display, screenId);
    wa.override_redirect = True;
    wa.colormap        = XCreateColormap(display, RootWindow(display, screenId), visual->visual, AllocNone);
    wa.event_mask      = ExposureMask;
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
