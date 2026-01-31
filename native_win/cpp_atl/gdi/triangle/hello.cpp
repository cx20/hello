#include <atlbase.h>
#include <atlwin.h> 
 
class CHelloWindow : public CWindowImpl<CHelloWindow>
{
public:
    BEGIN_MSG_MAP( CHelloWindow )
        MESSAGE_HANDLER( WM_PAINT,   OnPaint   )
        MESSAGE_HANDLER( WM_DESTROY, OnDestroy )
    END_MSG_MAP()
 
    LRESULT OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    LRESULT OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    void DrawTriangle(HDC hdc);
};

LRESULT CHelloWindow::OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint( &ps );
    DrawTriangle(hdc);
    EndPaint( &ps );
    return 0;
}

LRESULT CHelloWindow::OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    PostQuitMessage( 0 );
    return 0;
}

void CHelloWindow::DrawTriangle(HDC hdc)
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

    GradientFill(hdc, vertex, 3, &gTriangle, 1, GRADIENT_FILL_TRIANGLE);
}
 
CComModule _Module;
 
int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
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
