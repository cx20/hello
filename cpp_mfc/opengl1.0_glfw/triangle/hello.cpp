#include <afxwin.h>
#include <tchar.h>

#define GLEW_STATIC
#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
 
class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);
protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnPaint();
    DECLARE_MESSAGE_MAP()
    
    GLFWwindow* m_pWindow;
};
 
class CHelloApp : public CWinApp
{
public:
    BOOL InitInstance();
};
 
BOOL CHelloApp::InitInstance()
{
    m_pMainWnd = new CMainFrame;
    m_pMainWnd->ShowWindow(m_nCmdShow);
    m_pMainWnd->UpdateWindow();
    return TRUE;
}
 
CHelloApp App;
 
BEGIN_MESSAGE_MAP( CMainFrame, CFrameWnd )
    ON_WM_CREATE()
    ON_WM_PAINT()
END_MESSAGE_MAP()
 
CMainFrame::CMainFrame()
{
    Create( NULL, _T("Hello, World!") );
}
 
BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    CFrameWnd::PreCreateWindow(cs);
    cs.cx = 640;
    cs.cy = 480;

    glfwInit();

    return TRUE;
}

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    CFrameWnd::OnCreate(lpCreateStruct);

    m_pWindow = glfwCreateWindow(640, 480, "", NULL, NULL);
    glfwMakeContextCurrent( m_pWindow );
    glfwSetWindowPos(m_pWindow, 0, 0);

    HWND hwNative = glfwGetWin32Window(m_pWindow);
    ::SetParent(hwNative, m_hWnd);
    
    return  0;
}
 
void CMainFrame::OnPaint()
{
    glBegin(GL_TRIANGLES);

        glColor3f(1.0f, 0.0f, 0.0f);   glVertex2f( 0.0f,  0.50f);
        glColor3f(0.0f, 1.0f, 0.0f);   glVertex2f( 0.5f, -0.50f);
        glColor3f(0.0f, 0.0f, 1.0f);   glVertex2f(-0.5f, -0.50f);

    glEnd();
    
    glfwSwapBuffers( m_pWindow );
}
