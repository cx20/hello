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

    void glEnableClientState(GLenum array);
    void glVertexPointer(GLint size, GLenum type, GLsizei stride, const GLfloat* pointer);
    void glColorPointer(GLint size, GLenum type, GLsizei stride, const GLfloat* pointer);
    void glDrawArrays(GLenum mode, GLint first, GLsizei count);

    enum GL_COLOR_ARRAY = 0x8076;
    enum GL_VERTEX_ARRAY = 0x8074;
    enum GL_FLOAT = 0x1406;
    enum GL_TRIANGLE_STRIP = 0x0005;
}

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
    return cast(int)msg.wParam;
}

extern (Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow {
    static HGLRC hglrc;
    static HDC hdc;

    try {
        switch (message) {
            case WM_CREATE:
                hdc = GetDC(hwnd);
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
                ValidateRect(hwnd, null);
                return 0;

            case WM_DESTROY:
                wglMakeCurrent(null, null);
                wglDeleteContext(hglrc);
                ReleaseDC(hwnd, hdc);
                PostQuitMessage(0);
                return 0;

            default:
                return DefWindowProc(hwnd, message, wParam, lParam);
        }
    } catch (Throwable) {
        return DefWindowProc(hwnd, message, wParam, lParam);
    }
}

void render() {
    GLfloat[9] colors = [
         1.0f,  0.0f,  0.0f,
         0.0f,  1.0f,  0.0f,
         0.0f,  0.0f,  1.0f
    ];

    GLfloat[6] vertices = [
         0.0f,  0.5f,
         0.5f, -0.5f,
        -0.5f, -0.5f
    ];

    glEnableClientState(GL_COLOR_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);

    glColorPointer(3, GL_FLOAT, 0, colors.ptr);
    glVertexPointer(2, GL_FLOAT, 0, vertices.ptr);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 3);
}
