#include <afxwin.h>
#include <tchar.h>
#include <gl/gl.h>

class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);

protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnPaint();
    afx_msg void OnDestroy();
    DECLARE_MESSAGE_MAP()

public:
    void EnableOpenGL();
    void DisableOpenGL();
    void DrawTriangle();

private:
    CClientDC* m_pDC;
    HGLRC m_hRC;
};

class CHelloApp : public CWinApp
{
public:
    virtual BOOL InitInstance();
};

BOOL CHelloApp::InitInstance()
{
    CWinApp::InitInstance();
    m_pMainWnd = new CMainFrame;
    m_pMainWnd->ShowWindow(m_nCmdShow);
    m_pMainWnd->UpdateWindow();
    return TRUE;
}


CHelloApp App;

BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_PAINT()
    ON_WM_DESTROY()
END_MESSAGE_MAP()

CMainFrame::CMainFrame()
{
    m_pDC = NULL;
    m_hRC = NULL;
    Create(NULL, _T("Hello, World!"));
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    CFrameWnd::PreCreateWindow(cs);
    cs.cx = 640;
    cs.cy = 480;
    return TRUE;
}

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    CFrameWnd::OnCreate(lpCreateStruct);

    EnableOpenGL();

    return 0;
}

void CMainFrame::OnPaint()
{
    CPaintDC dc(this);
    
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    DrawTriangle();

    SwapBuffers(m_pDC->m_hDC);
}

void CMainFrame::OnDestroy()
{
    CFrameWnd::OnDestroy();

    DisableOpenGL();
}

void CMainFrame::EnableOpenGL()
{
    PIXELFORMATDESCRIPTOR pfd;

    m_pDC = new CClientDC(this);

    int iFormat;

    ZeroMemory(&pfd, sizeof(pfd));

    pfd.nSize      = sizeof(pfd);
    pfd.nVersion   = 1;
    pfd.dwFlags    = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    pfd.iPixelType = PFD_TYPE_RGBA;
    pfd.cColorBits = 24;
    pfd.cDepthBits = 16;
    pfd.iLayerType = PFD_MAIN_PLANE;

    iFormat = ChoosePixelFormat(m_pDC->m_hDC, &pfd);

    SetPixelFormat(m_pDC->m_hDC, iFormat, &pfd);

    m_hRC = wglCreateContext(m_pDC->m_hDC);
    wglMakeCurrent(m_pDC->m_hDC, m_hRC);
}

void CMainFrame::DisableOpenGL()
{
    wglMakeCurrent(NULL, NULL);
    wglDeleteContext(m_hRC);
    delete m_pDC;
}

void CMainFrame::DrawTriangle()
{
    glBegin(GL_TRIANGLES);

    glColor3f(1.0f, 0.0f, 0.0f);   glVertex2f( 0.0f,  0.50f);
    glColor3f(0.0f, 1.0f, 0.0f);   glVertex2f( 0.5f, -0.50f);
    glColor3f(0.0f, 0.0f, 1.0f);   glVertex2f(-0.5f, -0.50f);

    glEnd();
}