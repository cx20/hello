#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>

#define GLEW_STATIC
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

class CHelloWindow : public CWindowImpl<CHelloWindow>
{
public:
    BEGIN_MSG_MAP( CHelloWindow )
        MSG_WM_CREATE  ( OnCreate  )
        MSG_WM_PAINT   ( OnPaint   )
        MSG_WM_DESTROY ( OnDestroy )
    END_MSG_MAP()
 
    LRESULT OnCreate(LPCREATESTRUCT lpcs);
    void OnPaint( HDC hDC );
    void OnDestroy();

    void InitOpenGL();
    void DrawTriangle();

private:
    GLFWwindow* m_window;
};

LRESULT CHelloWindow::OnCreate(LPCREATESTRUCT lpcs)
{
    InitOpenGL();
    
    ResizeClient( 640, 480 );
    
    return 0L;
}

void CHelloWindow::OnPaint( HDC hDC )
{
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    DrawTriangle();

    glfwSwapBuffers( m_window );
}

void CHelloWindow::OnDestroy()
{
    PostQuitMessage( 0 );
 
    glfwTerminate();
}

void CHelloWindow::InitOpenGL()
{
    glfwInit();

    glfwWindowHint( GLFW_CONTEXT_VERSION_MAJOR, 1 );
    glfwWindowHint( GLFW_CONTEXT_VERSION_MINOR, 0 );
    
    m_window = glfwCreateWindow( 640, 480, "Hello, World!", NULL, NULL );
    glfwMakeContextCurrent( m_window );
    glfwSetWindowPos(m_window, 0, 0);
    
    HWND hwNative = glfwGetWin32Window(m_window);
    ::SetParent(hwNative, m_hWnd);

    glewInit();
}

void CHelloWindow::DrawTriangle()
{
    glBegin(GL_TRIANGLES);

    glColor3f(1.0f, 0.0f, 0.0f);   glVertex2f( 0.0f,  0.50f);
    glColor3f(0.0f, 1.0f, 0.0f);   glVertex2f( 0.5f, -0.50f);
    glColor3f(0.0f, 0.0f, 1.0f);   glVertex2f(-0.5f, -0.50f);

    glEnd();
}

CAppModule _Module;
 
int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);
 
    CMessageLoop theLoop;
    _Module.AddMessageLoop(&theLoop);
 
    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    int nRet = theLoop.Run();
 
    _Module.RemoveMessageLoop();
    _Module.Term();
 
    return nRet;
}