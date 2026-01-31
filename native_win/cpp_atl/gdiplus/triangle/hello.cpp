#include <atlbase.h>
#include <atlwin.h> 

#include <gdiplus.h>

using namespace Gdiplus;

class CHelloWindow : public CWindowImpl<CHelloWindow>
{
    BEGIN_MSG_MAP( CHelloWindow )
        MESSAGE_HANDLER( WM_PAINT,   OnPaint   )
        MESSAGE_HANDLER( WM_DESTROY, OnDestroy )
    END_MSG_MAP()
 
    LRESULT OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    LRESULT OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    void DrawTriangle( HDC hDC );
};
 
LRESULT CHelloWindow::OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    HDC hDC = GetDC();
    DrawTriangle(hDC);
    return 0;
}

LRESULT CHelloWindow::OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    PostQuitMessage( 0 );
    return 0;
}

void CHelloWindow::DrawTriangle(HDC hDC) 
{
    int WIDTH  = 640;
    int HEIGHT = 480;

    Graphics graphics(hDC);

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

CComModule _Module;
 
int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR           gdiplusToken;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

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
