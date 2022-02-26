#include <atlbase.h>
#include <atlwin.h>
#include <gl/gl.h>
 
class CHelloWindow : public CWindowImpl<CHelloWindow>
{
    BEGIN_MSG_MAP( CHelloWindow )
        MESSAGE_HANDLER( WM_CREATE,  OnCreate  )
        MESSAGE_HANDLER( WM_PAINT,   OnPaint   )
        MESSAGE_HANDLER( WM_DESTROY, OnDestroy )
    END_MSG_MAP()

    LRESULT OnCreate( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    LRESULT OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    LRESULT OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    
public:
    HGLRC EnableOpenGL(HDC hDC);
    void DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC);
    void DrawTriangle();

private:
     HDC   m_hDC;
     HGLRC m_hRC;
};


LRESULT CHelloWindow::OnCreate( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    m_hDC = GetDC();
    m_hRC = EnableOpenGL( m_hDC );
    
    ResizeClient( 640, 480 );
    glViewport( 0, 0, 640, 480 );
    
    return 0L;
}

LRESULT CHelloWindow::OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    DrawTriangle();

    SwapBuffers(m_hDC);
    
    return 0;
}

LRESULT CHelloWindow::OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    PostQuitMessage( 0 );

    DisableOpenGL( m_hWnd, m_hDC, m_hRC);

    return 0;
}

HGLRC CHelloWindow::EnableOpenGL(HDC hDC)
{
    HGLRC hRC = NULL;
    
    PIXELFORMATDESCRIPTOR pfd;

    int iFormat;

    ZeroMemory(&pfd, sizeof(pfd));

    pfd.nSize = sizeof(pfd);
    pfd.nVersion = 1;
    pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 24;
    pfd.cDepthBits = 16;
    pfd.iLayerType = PFD_MAIN_PLANE;

    iFormat = ChoosePixelFormat(hDC, &pfd);

    SetPixelFormat(hDC, iFormat, &pfd);

    hRC = wglCreateContext(hDC);
    wglMakeCurrent(hDC, hRC);
    
    return  hRC;
}

void CHelloWindow::DisableOpenGL(HWND hWnd, HDC hDC, HGLRC hRC)
{
    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(hRC);
    ReleaseDC(m_hDC);
}

void CHelloWindow::DrawTriangle()
{
    glBegin(GL_TRIANGLES);

    glColor3f(1.0f, 0.0f, 0.0f);   glVertex2f( 0.0f,  0.50f);
    glColor3f(0.0f, 1.0f, 0.0f);   glVertex2f( 0.5f, -0.50f);
    glColor3f(0.0f, 0.0f, 1.0f);   glVertex2f(-0.5f, -0.50f);

    glEnd();
}

CComModule _Module;

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);
 
    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    wnd.ResizeClient( 640, 480 );
    MSG msg;
    while( GetMessage( &msg, NULL, 0, 0 ) ){
        TranslateMessage( &msg );
        DispatchMessage( &msg );
    }
 
    _Module.Term();
 
    return msg.wParam;
}