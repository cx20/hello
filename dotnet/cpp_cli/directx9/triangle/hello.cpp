#include <tchar.h>
#include <d3d9.h>

struct VERTEX
{
    FLOAT x, y, z, rhw;
    DWORD color;
};

LPDIRECT3D9             g_pD3D = NULL;
LPDIRECT3DDEVICE9       g_pd3dDevice = NULL;
LPDIRECT3DVERTEXBUFFER9 g_pVB = NULL;

#define D3DFVF_VERTEX (D3DFVF_XYZRHW | D3DFVF_DIFFUSE)

LRESULT WINAPI WndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam );
HRESULT InitD3D( HWND hWnd );
HRESULT InitVB();
void Cleanup();
void Render();

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    UNREFERENCED_PARAMETER( hPrevInstance );
    UNREFERENCED_PARAMETER( lpCmdLine );

    LPCTSTR lpszClassName = _T("helloWindow");
    LPCTSTR lpszWindowName = _T("Hello, World!");

    WNDCLASSEX wcex = { 0 };
    wcex.cbSize         = sizeof(WNDCLASSEX);
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
    RegisterClassEx( &wcex );

    HWND hWnd = CreateWindow(
        lpszClassName,
        lpszWindowName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
        NULL, NULL, hInstance, NULL
    );

    if( FAILED( InitD3D( hWnd ) ) )
        return 0;

    if( FAILED( InitVB() ) )
        return 0;

    ShowWindow( hWnd, SW_SHOWDEFAULT );
    UpdateWindow( hWnd );

    MSG msg = { 0 };
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

    UnregisterClass( lpszClassName, wcex.hInstance );
    return 0;
}

LRESULT WINAPI WndProc( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam )
{
    switch( msg )
    {
        case WM_DESTROY:
            Cleanup();
            PostQuitMessage( 0 );
            return 0;
    }

    return DefWindowProc( hWnd, msg, wParam, lParam );
}

HRESULT InitD3D( HWND hWnd )
{
    if( NULL == ( g_pD3D = Direct3DCreate9( D3D_SDK_VERSION ) ) )
        return E_FAIL;

    D3DPRESENT_PARAMETERS d3dpp = { 0 };
    d3dpp.Windowed         = TRUE;
    d3dpp.SwapEffect       = D3DSWAPEFFECT_DISCARD;
    d3dpp.BackBufferFormat = D3DFMT_UNKNOWN;

    if( FAILED( g_pD3D->CreateDevice( D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, hWnd,
                                      D3DCREATE_SOFTWARE_VERTEXPROCESSING,
                                      &d3dpp, &g_pd3dDevice ) ) )
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

    if( FAILED( g_pd3dDevice->CreateVertexBuffer( 3 * sizeof( VERTEX ),
                                                  0, D3DFVF_VERTEX,
                                                  D3DPOOL_DEFAULT, &g_pVB, NULL ) ) )
    {
        return E_FAIL;
    }

    VOID* pVertices;
    if( FAILED( g_pVB->Lock( 0, sizeof( vertices ), ( void** )&pVertices, 0 ) ) )
        return E_FAIL;
    memcpy( pVertices, vertices, sizeof( vertices ) );
    g_pVB->Unlock();

    return S_OK;
}

void Cleanup()
{
    if( g_pVB != NULL )
        g_pVB->Release();

    if( g_pd3dDevice != NULL )
        g_pd3dDevice->Release();

    if( g_pD3D != NULL )
        g_pD3D->Release();
}

void Render()
{
    g_pd3dDevice->Clear( 0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB( 255, 255, 255 ), 1.0f, 0 );

    if( SUCCEEDED( g_pd3dDevice->BeginScene() ) )
    {
        g_pd3dDevice->SetStreamSource( 0, g_pVB, 0, sizeof( VERTEX ) );
        g_pd3dDevice->SetFVF( D3DFVF_VERTEX );
        g_pd3dDevice->DrawPrimitive( D3DPT_TRIANGLELIST, 0, 1 );

        g_pd3dDevice->EndScene();
    }

    g_pd3dDevice->Present( NULL, NULL, NULL, NULL );
}
