#include <atlbase.h>
#include <atlwin.h>
#include <d3d9.h>
#include <d3dx9.h>

struct VERTEX
{
    FLOAT x, y, z, rhw;
    DWORD color;
};

#define D3DFVF_VERTEX (D3DFVF_XYZRHW | D3DFVF_DIFFUSE)

class CHelloWindow : public CWindowImpl<CHelloWindow>
{
public:
    CHelloWindow();

    BEGIN_MSG_MAP( CHelloWindow )
        MESSAGE_HANDLER( WM_PAINT,   OnPaint   )
        MESSAGE_HANDLER( WM_DESTROY, OnDestroy )
    END_MSG_MAP()

    LRESULT OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    LRESULT OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled );
    HRESULT InitD3D();
    HRESULT InitVB();
    VOID Cleanup();
    VOID Render();

private:
    LPDIRECT3D9             m_pD3D;
    LPDIRECT3DDEVICE9       m_pd3dDevice;
    LPDIRECT3DVERTEXBUFFER9 m_pd3dVB;
    RECT                    m_rect;
};

CHelloWindow::CHelloWindow()
{
    m_pD3D       = NULL;
    m_pd3dDevice = NULL;
    m_pd3dVB     = NULL;

    memset( &m_rect, 0, sizeof(m_rect) );
}

LRESULT CHelloWindow::OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    Render();
    return 0;
}

LRESULT CHelloWindow::OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
{
    Cleanup();
    PostQuitMessage( 0 );
    return 0;
}

HRESULT CHelloWindow::InitD3D()
{
    HRESULT hr;
    m_pD3D = Direct3DCreate9( D3D_SDK_VERSION );
    if( m_pD3D == NULL )
    {
        return E_FAIL;
    }

    D3DPRESENT_PARAMETERS d3dpp;
    d3dpp.BackBufferWidth             = 0;
    d3dpp.BackBufferHeight            = 0;
    d3dpp.BackBufferFormat            = D3DFMT_UNKNOWN;
    d3dpp.BackBufferCount             = 0;
    d3dpp.MultiSampleType             = D3DMULTISAMPLE_NONE;
    d3dpp.MultiSampleQuality          = 0;
    d3dpp.SwapEffect                  = D3DSWAPEFFECT_DISCARD;
    d3dpp.hDeviceWindow               = NULL;
    d3dpp.Windowed                    = TRUE;
    d3dpp.EnableAutoDepthStencil      = 0;
    d3dpp.AutoDepthStencilFormat      = D3DFMT_UNKNOWN;
    d3dpp.Flags                       = 0;
    d3dpp.FullScreen_RefreshRateInHz  = 0;
    d3dpp.PresentationInterval        = 0;

    hr = m_pD3D->CreateDevice( D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, m_hWnd,
                                      D3DCREATE_SOFTWARE_VERTEXPROCESSING,
                                      &d3dpp, &m_pd3dDevice );
    if( FAILED( hr ) )
    {
        return E_FAIL;
    }

    return S_OK;
}

HRESULT CHelloWindow::InitVB()
{
    VERTEX vertices[] =
    {
        { 300.0f, 100.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(255, 0, 0) },
        { 500.0f, 400.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 255, 0) },
        { 100.0f, 400.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 0, 255) },
    };

    if( FAILED( m_pd3dDevice->CreateVertexBuffer( 3 * sizeof( VERTEX ),
                                                  0, D3DFVF_VERTEX,
                                                  D3DPOOL_DEFAULT, &m_pd3dVB, NULL ) ) )
    {
        return E_FAIL;
    }

    VOID* pVertices;
    if( FAILED( m_pd3dVB->Lock( 0, sizeof( vertices ), ( void** )&pVertices, 0 ) ) )
        return E_FAIL;
    memcpy( pVertices, vertices, sizeof( vertices ) );
    m_pd3dVB->Unlock();

    return S_OK;
}

VOID CHelloWindow::Cleanup()
{
    if ( m_pd3dVB != NULL )
    {
        m_pd3dVB->Release();
    }

    if( m_pd3dDevice != NULL )
    {
        m_pd3dDevice->Release();
    }

    if( m_pD3D != NULL )
    {
        m_pD3D->Release();
    }
}

VOID CHelloWindow::Render()
{
    if( m_pd3dDevice == NULL )
    {
        return;
    }

    if ( m_pd3dVB == NULL )
    {
        return;
    }

    m_pd3dDevice->Clear( 0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB( 255, 255, 255 ), 1.0f, 0 );

    if( SUCCEEDED( m_pd3dDevice->BeginScene() ) )
    {
        m_pd3dDevice->SetStreamSource( 0, m_pd3dVB, 0, sizeof( VERTEX ) );
        m_pd3dDevice->SetFVF( D3DFVF_VERTEX );
        m_pd3dDevice->DrawPrimitive( D3DPT_TRIANGLELIST, 0, 1 );

        m_pd3dDevice->EndScene();
    }

    m_pd3dDevice->Present( NULL, NULL, NULL, NULL );
}

CComModule _Module;

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);

    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    wnd.ResizeClient( 640, 480 );
    wnd.InitD3D();
    wnd.InitVB();
    MSG msg;
    while( GetMessage( &msg, NULL, 0, 0 ) ){
        TranslateMessage( &msg );
        DispatchMessage( &msg );
    }

    _Module.Term();

    return (int)msg.wParam;
}