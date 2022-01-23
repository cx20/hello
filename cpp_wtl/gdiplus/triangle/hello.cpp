#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>

#include <gdiplus.h>
using namespace Gdiplus;
 
class CHelloWindow : public CWindowImpl<CHelloWindow>
{
    BEGIN_MSG_MAP( CHelloWindow )
        MSG_WM_PAINT   ( OnPaint   )
        MSG_WM_DESTROY ( OnDestroy )
    END_MSG_MAP()
     
    void OnPaint( HDC /* hDC */ );
    void OnDestroy();
    void DrawTriangle( HDC hDC );
};

void CHelloWindow::OnPaint( HDC /* hDC */ )
{
    HDC hDC = GetDC();
    DrawTriangle(hDC);
}

void CHelloWindow::OnDestroy()
{
    PostQuitMessage( 0 );
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

CAppModule _Module;
 
int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    GdiplusStartupInput gdiplusStartupInput;
    ULONG_PTR           gdiplusToken;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

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