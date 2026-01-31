#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>
#include <gl/gl.h>
 
class CHelloWindow : public CWindowImpl<CHelloWindow>
{
    BEGIN_MSG_MAP( CHelloWindow )
        MSG_WM_CREATE  ( OnCreate  )
        MSG_WM_PAINT   ( OnPaint   )
        MSG_WM_DESTROY ( OnDestroy )
    END_MSG_MAP()
 
    LRESULT OnCreate(LPCREATESTRUCT lpcs);
    void OnPaint( HDC hDC );
    void OnDestroy();
public:
    void EnableOpenGL();
    void DisableOpenGL();
    void DrawTriangle();

private:
    HDC   m_hDC;
    HGLRC m_hRC;
};


LRESULT CHelloWindow::OnCreate(LPCREATESTRUCT lpcs)
{
    EnableOpenGL();
    
    ResizeClient( 640, 480 );
    glViewport( 0, 0, 640, 480 );
    
    return 0L;
}

void CHelloWindow::OnPaint( HDC hDC )
{
    CPaintDC dc(m_hWnd);

    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    DrawTriangle();

    dc.SwapBuffers();
}

void CHelloWindow::OnDestroy()
{
    PostQuitMessage( 0 );

    DisableOpenGL();
}

void CHelloWindow::EnableOpenGL()
{
    CClientDC dc(m_hWnd);

    PIXELFORMATDESCRIPTOR pfd;

    int iFormat;

    ZeroMemory(&pfd, sizeof(pfd));

    pfd.nSize      = sizeof(pfd);
    pfd.nVersion   = 1;
    pfd.dwFlags    = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 24;
    pfd.cDepthBits = 16;
    pfd.iLayerType = PFD_MAIN_PLANE;

    iFormat = dc.ChoosePixelFormat(&pfd);

    dc.SetPixelFormat(iFormat, &pfd);

    m_hRC = dc.wglCreateContext();
    dc.wglMakeCurrent(m_hRC);
}

void CHelloWindow::DisableOpenGL()
{
    CClientDC dc(m_hWnd);
    dc.wglMakeCurrent(NULL);
    ::wglDeleteContext(m_hRC);
    m_hRC = NULL;
}

void CHelloWindow::DrawTriangle()
{
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

CAppModule _Module;
 
int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);
 
    CMessageLoop theLoop;
    _Module.AddMessageLoop(&theLoop);
 
    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    wnd.ResizeClient( 640, 480 );
    int nRet = theLoop.Run();
 
    _Module.RemoveMessageLoop();
    _Module.Term();
 
    return nRet;
}