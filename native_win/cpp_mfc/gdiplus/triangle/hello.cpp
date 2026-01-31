#include <afxwin.h>
#include <tchar.h>
 
#include <gdiplus.h>
using namespace Gdiplus;

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
    virtual BOOL InitInstance();
    virtual int ExitInstance();
private:
    GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR           gdiplusToken;
};
 
BOOL CHelloApp::InitInstance()
{
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);

    m_pMainWnd = new CMainFrame;
    m_pMainWnd->ShowWindow(m_nCmdShow);
    m_pMainWnd->UpdateWindow();
    return TRUE;
}

int CHelloApp::ExitInstance()
{
    GdiplusShutdown(gdiplusToken);
    return CWinApp::ExitInstance();
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

    CDC* pDC = GetDC();
    Graphics graphics(pDC->m_hDC);

    Point points[] = {
        Point(WIDTH * 1 / 2, HEIGHT * 1 / 4),
        Point(WIDTH * 3 / 4, HEIGHT * 3 / 4),
        Point(WIDTH * 1 / 4, HEIGHT * 3 / 4)
    };

    GraphicsPath path;
    path.AddLines(points, 3);

    PathGradientBrush pthGrBrush(&path);

    Color centercolor = Color(255, 255/3, 255/3, 255/3);
    pthGrBrush.SetCenterColor(centercolor);
    
    Color colors[] = {
        Color(255, 255,   0,   0),  // red
        Color(255,   0, 255,   0),  // green
        Color(255,   0,   0, 255)   // blue
    };

    int count = 3;
    pthGrBrush.SetSurroundColors(colors, &count);

    graphics.FillPath(&pthGrBrush, &path);
}
