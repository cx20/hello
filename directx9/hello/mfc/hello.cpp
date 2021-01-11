#include <afxwin.h>
#include <tchar.h>
#include <tchar.h>
#include <d3d9.h>
#include <d3dx9.h>

class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    ~CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs);

    HRESULT InitD3D();
    HRESULT InitFont();
    VOID Cleanup();
    VOID Render();
protected:
    afx_msg void OnPaint();
    DECLARE_MESSAGE_MAP()

private:
    LPDIRECT3D9         m_pD3D;
    LPDIRECT3DDEVICE9   m_pd3dDevice;
    LPD3DXFONT          m_pd3dFont;
    RECT                m_rect;
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
    m_pD3D       = NULL;
    m_pd3dDevice = NULL;
    m_pd3dFont   = NULL;

    memset( &m_rect, 0, sizeof(m_rect) );

    Create( NULL, _T("Hello, World!") );

    InitD3D();
    InitFont();
}

CMainFrame::~CMainFrame()
{
    Cleanup();
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
    Render();
}

HRESULT CMainFrame::InitD3D()
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

HRESULT CMainFrame::InitFont()
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
    lstrcpy( lf.FaceName, _T("�l�r �S�V�b�N") );

    hr = D3DXCreateFontIndirect(m_pd3dDevice, &lf, &m_pd3dFont );
    if ( FAILED( hr ) )
    {
        Cleanup();
        return hr;
    }

    hr = m_pd3dFont->DrawText(
        NULL,
        _T("Hello, DirectX(MFC) World!"),
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

VOID CMainFrame::Cleanup()
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

VOID CMainFrame::Render()
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
            _T("Hello, DirectX(MFC) World!"),
            -1,
            &m_rect,
            DT_LEFT | DT_SINGLELINE, 0xffffffff
        );

        m_pd3dDevice->EndScene();
    }

    m_pd3dDevice->Present( NULL, NULL, NULL, NULL );
}