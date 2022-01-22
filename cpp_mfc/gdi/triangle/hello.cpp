#include <afxwin.h>
#include <tchar.h>
 
class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);
protected:
    afx_msg void OnPaint();
    DECLARE_MESSAGE_MAP()
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
    return TRUE;
}
 
void CMainFrame::OnPaint()
{
    int WIDTH  = 640;
    int HEIGHT = 480;

    TRIVERTEX vertex[3];
    vertex[0].x     = WIDTH  * 1 / 2;
    vertex[0].y     = HEIGHT * 1 / 4;
    vertex[0].Red   = 0xffff;
    vertex[0].Green = 0x0000;
    vertex[0].Blue  = 0x0000;
    vertex[0].Alpha = 0x0000;

    vertex[1].x     = WIDTH  * 3 / 4;
    vertex[1].y     = HEIGHT * 3 / 4;
    vertex[1].Red   = 0x0000;
    vertex[1].Green = 0xffff;
    vertex[1].Blue  = 0x0000;
    vertex[1].Alpha = 0x0000;

    vertex[2].x     = WIDTH  * 1 / 4;
    vertex[2].y     = HEIGHT * 3 / 4; 
    vertex[2].Red   = 0x0000;
    vertex[2].Green = 0x0000;
    vertex[2].Blue  = 0xffff;
    vertex[2].Alpha = 0x0000;

    GRADIENT_TRIANGLE gTriangle;
    gTriangle.Vertex1 = 0;
    gTriangle.Vertex2 = 1;
    gTriangle.Vertex3 = 2;

    CPaintDC dc(this);
    dc.GradientFill(vertex, 3, &gTriangle, 1, GRADIENT_FILL_TRIANGLE);
}
