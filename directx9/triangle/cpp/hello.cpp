#include <windows.h>
#include <tchar.h>
#include <d3d9.h>
#include <d3dx9.h>
 
LPDIRECT3D9         g_pD3D       = NULL;
LPDIRECT3DDEVICE9   g_pd3dDevice = NULL;
LPD3DXFONT          g_pd3dFont   = NULL;
RECT                g_rect       = { 0, 0, 0, 0 };

#define FVF_VERTEX   (D3DFVF_XYZRHW | D3DFVF_DIFFUSE)
typedef struct 
{
    float       x,y,z;
    float       rhw; 
    D3DCOLOR    diffuse;
} D3DVERTEX;

LPDIRECT3DVERTEXBUFFER9 pVertexBuffer = NULL;

D3DVERTEX vertices[] = 
{ 
    { 300.0f,   0.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(255, 0, 0) },
    { 600.0f, 500.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 255, 0) },
    { 0.0f,   500.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 0, 255) },
};

HRESULT InitD3D( HWND hWnd );
VOID Cleanup();
VOID Render();
 
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
 
VOID Cleanup()
{
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
 
    g_pd3dDevice->Clear( 0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB( 255, 255, 255 ), 1.0f, 0 );
 
    if( SUCCEEDED( g_pd3dDevice->BeginScene() ) )
    {
        g_pd3dDevice->SetFVF(FVF_VERTEX);
        g_pd3dDevice->DrawPrimitiveUP(D3DPT_TRIANGLELIST, 1, vertices, sizeof(D3DVERTEX)); 
        g_pd3dDevice->EndScene();
    }
 
    g_pd3dDevice->Present( NULL, NULL, NULL, NULL );
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
 
 
int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
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