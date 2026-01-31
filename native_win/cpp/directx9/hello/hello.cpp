#include <windows.h>
#include <tchar.h>
#include <d3d9.h>
#include <d3dx9.h>

LPDIRECT3D9         g_pD3D       = NULL;
LPDIRECT3DDEVICE9   g_pd3dDevice = NULL;
LPD3DXFONT          g_pd3dFont   = NULL;
RECT                g_rect       = { 0, 0, 0, 0 };

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
HRESULT InitD3D( HWND hWnd );
HRESULT InitFont();
VOID Cleanup();
VOID Render();

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    LPCTSTR lpszClassName = _T("helloWindow");
    LPCTSTR lpszWindowName = _T("Hello, World!");

    WNDCLASSEX wcex;
    wcex.cbSize = sizeof(WNDCLASSEX);
    wcex.style          = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc    = WndProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APPLICATION));
    wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
    wcex.lpszMenuName   = NULL;
    wcex.lpszClassName  = lpszClassName;
    wcex.hIconSm        = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APPLICATION));

    RegisterClassEx(&wcex);
    HWND hWnd = CreateWindow(
        lpszClassName,
        lpszWindowName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
        NULL, NULL, hInstance, NULL
        );

    InitD3D( hWnd );
    InitFont();

    ShowWindow( hWnd, SW_SHOWDEFAULT );
    UpdateWindow( hWnd );

    MSG msg;
    while( GetMessage( &msg, NULL, 0, 0 ) )
    {
        TranslateMessage( &msg );
        DispatchMessage( &msg );
    }

    return 0;
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch( message )
    {
        case WM_DESTROY:
            Cleanup();
            PostQuitMessage( 0 );
            return 0;

        case WM_PAINT:
            Render();
            ValidateRect( hWnd, NULL );
            return 0;
    }

    return DefWindowProc( hWnd, message, wParam, lParam );
}

HRESULT InitD3D( HWND hWnd )
{
    HRESULT hr;
    g_pD3D = Direct3DCreate9( D3D_SDK_VERSION );
    if( g_pD3D == NULL )
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

    hr = g_pD3D->CreateDevice( D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, hWnd,
                                      D3DCREATE_SOFTWARE_VERTEXPROCESSING,
                                      &d3dpp, &g_pd3dDevice );
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
    lstrcpy( lf.FaceName, _T("�l�r �S�V�b�N") );

    hr = D3DXCreateFontIndirect(g_pd3dDevice, &lf, &g_pd3dFont );
    if ( FAILED( hr ) )
    {
        Cleanup();
        return hr;
    }

    hr = g_pd3dFont->DrawText(
        NULL,
        _T("Hello, DirectX(C++) World!"),
        -1,
        &g_rect,
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
    if ( g_pd3dFont != NULL )
    {
        g_pd3dFont->Release();
    }

    if( g_pd3dDevice != NULL )
    {
        g_pd3dDevice->Release();
    }

    if( g_pD3D != NULL )
    {
        g_pD3D->Release();
    }
}

VOID Render()
{
    if( g_pd3dDevice == NULL )
    {
        return;
    }

    if ( g_pd3dFont == NULL )
    {
        return;
    }

    g_pd3dDevice->Clear( 0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB( 0, 0, 255 ), 1.0f, 0 );

    if( SUCCEEDED( g_pd3dDevice->BeginScene() ) )
    {
        g_pd3dFont->DrawText(
            NULL,
            _T("Hello, DirectX(C++) World!"),
            -1,
            &g_rect,
            DT_LEFT | DT_SINGLELINE, 0xffffffff
        );

        g_pd3dDevice->EndScene();
    }

    g_pd3dDevice->Present( NULL, NULL, NULL, NULL );
}

