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
    CPaintDC dc(this);
    dc.TextOut( 0, 0, _T("Hello, Win32 GUI(MFC) World!") );
}
