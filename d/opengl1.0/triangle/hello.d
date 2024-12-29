import core.runtime;
import core.sys.windows.windows;
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;

extern(System) {
    alias GLenum = uint;
    alias GLuint = uint;
    alias GLint = int;
    alias GLsizei = int;
    alias GLbitfield = uint;
    alias GLfloat = float;

    void glClear(GLbitfield mask);
    void glClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    void glBegin(GLenum mode);
    void glEnd();
    void glVertex2f(GLfloat x, GLfloat y);
    void glColor3f(GLfloat red, GLfloat green, GLfloat blue);
}

enum GL_COLOR_BUFFER_BIT = 0x4000;
enum GL_TRIANGLES = 0x0004;

auto toUTF16z(S)(S s) {
    return cast(const(wchar)*)s.ptr;
}

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    Runtime.initialize();
    int result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);
    Runtime.terminate();
    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    string appName = "OpenGLTriangle";
    WNDCLASS wndclass = {};
    wndclass.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    wndclass.lpfnWndProc = &WndProc;
    wndclass.hInstance = hInstance;
    wndclass.lpszClassName = appName.toUTF16z;

    RegisterClass(&wndclass);

    HWND hwnd = CreateWindow(
        appName.toUTF16z,
        "Hello, World!",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        640,
        480,
        null,
        null,
        hInstance,
        null);

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    MSG msg;
    while (GetMessage(&msg, null, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return msg.wParam;
}

extern (Windows)
LRESULT WndProc(void* hwnd, uint message, uint wParam, int lParam) nothrow {
    static HGLRC hglrc;
    static HDC hdc;

    try {
        switch (message) {
            case WM_CREATE:
                hdc = GetDC(cast(HWND) hwnd);
                PIXELFORMATDESCRIPTOR pfd = PIXELFORMATDESCRIPTOR(
                    nSize: PIXELFORMATDESCRIPTOR.sizeof,
                    nVersion: 1,
                    dwFlags: PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
                    iPixelType: PFD_TYPE_RGBA,
                    cColorBits: 32,
                    cDepthBits: 24,
                    iLayerType: PFD_MAIN_PLANE
                );
                int format = ChoosePixelFormat(hdc, &pfd);
                SetPixelFormat(hdc, format, &pfd);
                hglrc = wglCreateContext(hdc);
                wglMakeCurrent(hdc, hglrc);
                return 0;

            case WM_PAINT:
                render();
                SwapBuffers(hdc);
                ValidateRect(cast(HWND) hwnd, null);
                return 0;

            case WM_DESTROY:
                wglMakeCurrent(null, null);
                wglDeleteContext(hglrc);
                ReleaseDC(cast(HWND) hwnd, hdc);
                PostQuitMessage(0);
                return 0;

            default:
                return DefWindowProc(cast(HWND) hwnd, message, wParam, lParam);
        }
    } catch (Throwable) {
        return DefWindowProc(cast(HWND) hwnd, message, wParam, lParam);
    }
}

void render() {
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glBegin(GL_TRIANGLES);
        glColor3f(1.0f, 0.0f, 0.0f); glVertex2f(-0.5f, -0.5f);
        glColor3f(0.0f, 1.0f, 0.0f); glVertex2f( 0.5f, -0.5f);
        glColor3f(0.0f, 0.0f, 1.0f); glVertex2f( 0.0f,  0.5f);
    glEnd();
}
