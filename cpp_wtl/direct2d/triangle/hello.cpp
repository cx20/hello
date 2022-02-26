#include <d2d1.h>
#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>
#include <atltypes.h>

class CHelloWindow : public CWindowImpl<CHelloWindow>
{
public:
    BEGIN_MSG_MAP( CHelloWindow )
        MSG_WM_CREATE  ( OnCreate  )
        MSG_WM_PAINT   ( OnPaint   )
        MSG_WM_SIZE    ( OnSize    )
        MSG_WM_DESTROY ( OnDestroy )
    END_MSG_MAP()
 
    HRESULT OnCreate(LPCREATESTRUCT lpCreateStruct);
    void OnPaint( HDC hDC );
    void OnSize(UINT /*type*/, CSize size);
    void OnDestroy();
    HRESULT CreateRenderTarget();
    void DrawTriangle();

private:
    CComPtr<ID2D1HwndRenderTarget> m_renderTarget;
};

HRESULT CHelloWindow::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    CreateRenderTarget();
    
    return 0;
}

void CHelloWindow::OnPaint( HDC hDC )
{
    DrawTriangle();
}

void CHelloWindow::OnSize(UINT /*type*/, CSize size)
{
    m_renderTarget->Resize(D2D1::SizeU(size.cx, size.cy));
}

void CHelloWindow::OnDestroy()
{
    PostQuitMessage( 0 );
}


HRESULT CHelloWindow::CreateRenderTarget()
{
    HRESULT hr = S_OK;

    CComPtr<ID2D1Factory> factory;
    hr = D2D1CreateFactory<ID2D1Factory>(D2D1_FACTORY_TYPE_SINGLE_THREADED, &factory);
    if( FAILED( hr ) )
        return hr;
    
    CComPtr<ID2D1HwndRenderTarget> renderTarget;
    hr = factory->CreateHwndRenderTarget(
        D2D1::RenderTargetProperties(), 
        D2D1::HwndRenderTargetProperties(m_hWnd), 
        &m_renderTarget
    );
    
    return hr;
}


void CHelloWindow::DrawTriangle()
{
    int WIDTH  = 640;
    int HEIGHT = 480;

    m_renderTarget->BeginDraw();
    m_renderTarget->Clear(D2D1::ColorF(D2D1::ColorF::White));

    D2D1_POINT_2F p1 = D2D1::Point2F(WIDTH * 1 / 2, HEIGHT * 1 / 4);
    D2D1_POINT_2F p2 = D2D1::Point2F(WIDTH * 3 / 4, HEIGHT * 3 / 4);
    D2D1_POINT_2F p3 = D2D1::Point2F(WIDTH * 1 / 4, HEIGHT * 3 / 4);
    
    CComPtr<ID2D1SolidColorBrush> brush;
    m_renderTarget->CreateSolidColorBrush(D2D1::ColorF(D2D1::ColorF::Blue), &brush);

    m_renderTarget->DrawLine(p1, p2, brush);
    m_renderTarget->DrawLine(p2, p3, brush);
    m_renderTarget->DrawLine(p3, p1, brush);

    m_renderTarget->EndDraw();
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