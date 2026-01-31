#include <afxwin.h>
#include <tchar.h>
 
class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);
protected:
    afx_msg void OnPaint();
    afx_msg LRESULT OnDraw2D(WPARAM wParam, LPARAM lParam);
    DECLARE_MESSAGE_MAP()

    CD2DSolidColorBrush* m_pBlueBrush;
    CD2DSolidColorBrush* m_pWhiteBrush;
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
    ON_REGISTERED_MESSAGE(AFX_WM_DRAW2D, &CMainFrame::OnDraw2D)
END_MESSAGE_MAP()
 
CMainFrame::CMainFrame()
{
    Create( NULL, _T("Hello, World!") );

    EnableD2DSupport();

    m_pBlueBrush = new CD2DSolidColorBrush(GetRenderTarget(), D2D1::ColorF(D2D1::ColorF::Blue));
    m_pWhiteBrush = new CD2DSolidColorBrush(GetRenderTarget(), D2D1::ColorF(D2D1::ColorF::White));
}
 
BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    CFrameWnd::PreCreateWindow(cs);
    cs.cx = 640;
    cs.cy = 480;
    return TRUE;
}

LRESULT CMainFrame::OnDraw2D(WPARAM wParam, LPARAM lParam)
{
    CHwndRenderTarget* pRenderTarget = (CHwndRenderTarget*)lParam;

    CRect rect;
    GetClientRect(rect);

    pRenderTarget->FillRectangle(rect, m_pWhiteBrush);

    int WIDTH  = 640;
    int HEIGHT = 480;

    D2D1_POINT_2F p1 = D2D1::Point2F(WIDTH * 1 / 2, HEIGHT * 1 / 4);
    D2D1_POINT_2F p2 = D2D1::Point2F(WIDTH * 3 / 4, HEIGHT * 3 / 4);
    D2D1_POINT_2F p3 = D2D1::Point2F(WIDTH * 1 / 4, HEIGHT * 3 / 4);

    pRenderTarget->DrawLine(p1, p2, m_pBlueBrush);
    pRenderTarget->DrawLine(p2, p3, m_pBlueBrush);
    pRenderTarget->DrawLine(p3, p1, m_pBlueBrush);
        
    return TRUE;
}
