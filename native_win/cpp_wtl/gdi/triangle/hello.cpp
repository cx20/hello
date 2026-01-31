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
        DrawTriangle();
    }
    void OnDestroy()
    {
        PostQuitMessage( 0 );
    }
    
    void DrawTriangle();
};


void CHelloWindow::DrawTriangle()
{
    CPaintDC dc( m_hWnd );

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

    dc.GradientFill(vertex, 3, &gTriangle, 1, GRADIENT_FILL_TRIANGLE);
}

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