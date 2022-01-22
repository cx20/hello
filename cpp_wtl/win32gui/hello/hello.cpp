#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>
 
class CHelloWindow : public CWindowImpl<CHelloWindow>
{
    BEGIN_MSG_MAP( CHelloWindow )
        MSG_WM_PAINT   ( OnPaint   )
        MSG_WM_DESTROY ( OnDestroy )
    END_MSG_MAP()
 
    void OnPaint( HDC hDC )
    {
        CPaintDC dc( m_hWnd );
        LPCTSTR lpszMessage = _T("Hello, Win32 GUI(WTL) World!");
        dc.TextOut( 0, 0, lpszMessage, lstrlen(lpszMessage) );
    }
    void OnDestroy()
    {
        PostQuitMessage( 0 );
    }
};
 
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