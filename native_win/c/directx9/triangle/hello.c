#include <tchar.h>
#include <d3d9.h>

typedef struct _VERTEX
{
    FLOAT x, y, z, rhw;
    DWORD color;
} VERTEX;

LPDIRECT3D9             g_pD3D       = NULL;
LPDIRECT3DDEVICE9       g_pd3dDevice = NULL;
LPDIRECT3DVERTEXBUFFER9 g_pVB        = NULL;

#define D3DFVF_VERTEX (D3DFVF_XYZRHW | D3DFVF_DIFFUSE)

LRESULT CALLBACK WndProc( HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam );
HRESULT InitD3D( HWND hWnd );
HRESULT InitVB();
VOID Cleanup();
VOID Render();

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    LPCTSTR lpszClassName = _T("helloWindow");
    LPCTSTR lpszWindowName = _T("Hello, World!");
    MSG msg = { 0 };
    HWND hWnd;

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
    hWnd = CreateWindow(
        lpszClassName,
        lpszWindowName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
        NULL, NULL, hInstance, NULL
    );

    InitD3D( hWnd );
    InitVB();

    ShowWindow( hWnd, SW_SHOWDEFAULT );
    UpdateWindow( hWnd );

    while( msg.message != WM_QUIT )
    {
        if( PeekMessage( &msg, NULL, 0U, 0U, PM_REMOVE ) )
        {
            TranslateMessage( &msg );
            DispatchMessage( &msg );
        }
        else
        {
            Render();
        }
    }

    return 0;
}

LRESULT CALLBACK WndProc( HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam )
{
    switch( message )
    {
        case WM_DESTROY:
            Cleanup();
            PostQuitMessage( 0 );
            return 0;
    }

    return DefWindowProc( hWnd, message, wParam, lParam );
}

HRESULT InitD3D( HWND hWnd )
{
    HRESULT hr;
    D3DPRESENT_PARAMETERS d3dpp;
    g_pD3D = Direct3DCreate9( D3D_SDK_VERSION );
    if( g_pD3D == NULL )
    {
        return E_FAIL;
    }

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

    hr = g_pD3D->lpVtbl->CreateDevice(
        g_pD3D,
        D3DADAPTER_DEFAULT,
        D3DDEVTYPE_HAL,
        hWnd,
        D3DCREATE_SOFTWARE_VERTEXPROCESSING,
        &d3dpp,
        &g_pd3dDevice
    );
    
    if( FAILED( hr ) )
    {
        return E_FAIL;
    }

    return S_OK;
}

HRESULT InitVB()
{
    VERTEX vertices[] =
    {
        { 300.0f, 100.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(255, 0, 0) },
        { 500.0f, 400.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 255, 0) },
        { 100.0f, 400.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 0, 255) },
    };

    if( FAILED( g_pd3dDevice->lpVtbl->CreateVertexBuffer( 
                                          g_pd3dDevice, 
                                          3 * sizeof( VERTEX ),
                                          0, 
                                          D3DFVF_VERTEX,
                                          D3DPOOL_DEFAULT,
                                          &g_pVB, 
                                          NULL ) ) )
    {
        return E_FAIL;
    }

    VOID* pVertices;
    if( FAILED( g_pVB->lpVtbl->Lock(g_pVB, 0, sizeof( vertices ), ( void** )&pVertices, 0 ) ) )
        return E_FAIL;
    memcpy( pVertices, vertices, sizeof( vertices ) );
    g_pVB->lpVtbl->Unlock(g_pVB);

    return S_OK;
}

VOID Cleanup()
{
    if( g_pVB != NULL )
    {
        g_pVB->lpVtbl->Release( g_pVB );
    }

    if( g_pd3dDevice != NULL )
    {
        g_pd3dDevice->lpVtbl->Release( g_pd3dDevice );
    }

    if( g_pD3D != NULL )
    {
        g_pD3D->lpVtbl->Release( g_pD3D );
    }
}

VOID Render()
{
    if( g_pd3dDevice == NULL )
    {
        return;
    }

    g_pd3dDevice->lpVtbl->Clear( g_pd3dDevice, 0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB( 255, 255, 255 ), 1.0f, 0 );

    if( SUCCEEDED( g_pd3dDevice->lpVtbl->BeginScene( g_pd3dDevice ) ) )
    {
        g_pd3dDevice->lpVtbl->SetStreamSource( g_pd3dDevice, 0, g_pVB, 0, sizeof( VERTEX ) );
        g_pd3dDevice->lpVtbl->SetFVF( g_pd3dDevice, D3DFVF_VERTEX );
        g_pd3dDevice->lpVtbl->DrawPrimitive( g_pd3dDevice, D3DPT_TRIANGLELIST, 0, 1 );

        g_pd3dDevice->lpVtbl->EndScene( g_pd3dDevice );
    }

    g_pd3dDevice->lpVtbl->Present( g_pd3dDevice, NULL, NULL, NULL, NULL );
}
