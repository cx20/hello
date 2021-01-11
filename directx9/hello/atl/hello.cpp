#include <atlbase.h>
#include <atlwin.h>
#include <d3d9.h>
#include <d3dx9.h>

class CHelloWindow : public CWindowImpl<CHelloWindow>
{
public:
    CHelloWindow()
    {
        m_pD3D       = NULL;
        m_pd3dDevice = NULL;
        m_pd3dFont   = NULL;

        memset( &m_rect, 0, sizeof(m_rect) );
    }

    BEGIN_MSG_MAP( CHelloWindow )
        MESSAGE_HANDLER( WM_PAINT,   OnPaint   )
        MESSAGE_HANDLER( WM_DESTROY, OnDestroy )
    END_MSG_MAP()

    LRESULT OnPaint( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
    {
        Render();
        return 0;
    }

    LRESULT OnDestroy( UINT uMsg, WPARAM wParam, LPARAM lParam, BOOL& bHandled )
    {
        Cleanup();
        PostQuitMessage( 0 );
        return 0;
    }

    HRESULT InitD3D()
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

    HRESULT InitFont()
    {
        HRESULT hr;
        D3DXFONT_DESC lf;
        lf.Height          = 16;
        lf.Width           = 0;
        lf.Weight          = 0;
        lf.MipLevels       = 1;
        lf.Italic          = 0;
        lf.CharSet         = SHIFTJIS_CHARSET;
        lf.OutputPrecision = OUT_TT_ONLY_PRECIS;
        lf.Quality         = PROOF_QUALITY;
        lf.PitchAndFamily  = FIXED_PITCH | FF_MODERN;
        lstrcpy( lf.FaceName, _T("‚l‚r ƒSƒVƒbƒN") );

        hr = D3DXCreateFontIndirect(m_pd3dDevice, &lf, &m_pd3dFont );
        if ( FAILED( hr ) )
        {
            Cleanup();
            return hr;
        }

        hr = m_pd3dFont->DrawText(
            NULL,
            _T("Hello, DirectX(ATL) World!"),
            -1,
            &m_rect,
            DT_CALCRECT | DT_LEFT | DT_SINGLELINE,
            0xffffffff
        );

        if ( FAILED( hr ) )
        {
            Cleanup();
            return hr;
        }

        return hr;
    }

    VOID Cleanup()
    {
        if ( m_pd3dFont != NULL )
        {
            m_pd3dFont->Release();
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

    VOID Render()
    {
        if( m_pd3dDevice == NULL )
        {
            return;
        }

        if ( m_pd3dFont == NULL )
        {
            return;
        }

        m_pd3dDevice->Clear( 0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB( 0, 0, 255 ), 1.0f, 0 );

        if( SUCCEEDED( m_pd3dDevice->BeginScene() ) )
        {
            m_pd3dFont->DrawText(
                NULL,
                _T("Hello, DirectX(ATL) World!"),
                -1,
                &m_rect,
                DT_LEFT | DT_SINGLELINE, 0xffffffff
            );

            m_pd3dDevice->EndScene();
        }

        m_pd3dDevice->Present( NULL, NULL, NULL, NULL );
    }

private:
    LPDIRECT3D9         m_pD3D;
    LPDIRECT3DDEVICE9   m_pd3dDevice;
    LPD3DXFONT          m_pd3dFont;
    RECT                m_rect;
};

CComModule _Module;

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);

    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    wnd.ResizeClient( 640, 480 );
    wnd.InitD3D();
    wnd.InitFont();
    MSG msg;
    while( GetMessage( &msg, NULL, 0, 0 ) ){
        TranslateMessage( &msg );
        DispatchMessage( &msg );
    }

    _Module.Term();

    return (int)msg.wParam;
}