#include <windows.h>
#include <tchar.h>
#include <d3d10.h>
#include <d3dcompiler.h>

typedef struct _VERTEX
{
    FLOAT x, y, z;
    FLOAT r, g, b, a;
} VERTEX;

HINSTANCE               g_hInst = NULL;
HWND                    g_hWnd = NULL;
D3D10_DRIVER_TYPE       g_driverType = D3D10_DRIVER_TYPE_NULL;
ID3D10Device*           g_pd3dDevice = NULL;
IDXGISwapChain*         g_pSwapChain = NULL;
ID3D10RenderTargetView* g_pRenderTargetView = NULL;
ID3D10VertexShader*     g_pVertexShader = NULL;
ID3D10PixelShader*      g_pPixelShader = NULL;
ID3D10InputLayout*      g_pVertexLayout = NULL;
ID3D10Buffer*           g_pVertexBuffer = NULL;

LRESULT CALLBACK    WndProc( HWND, UINT, WPARAM, LPARAM );
HRESULT InitWindow( HINSTANCE hInstance, int nCmdShow );
HRESULT InitDevice();
void CleanupDevice();
void Render();

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    UNREFERENCED_PARAMETER( hPrevInstance );
    UNREFERENCED_PARAMETER( lpCmdLine );

    if( FAILED( InitWindow( hInstance, nCmdShow ) ) )
        return 0;

    if( FAILED( InitDevice() ) )
    {
        CleanupDevice();
        return 0;
    }

    MSG msg = {0};
    while( WM_QUIT != msg.message )
    {
        if( PeekMessage( &msg, NULL, 0, 0, PM_REMOVE ) )
        {
            TranslateMessage( &msg );
            DispatchMessage( &msg );
        }
        else
        {
            Render();
        }
    }

    CleanupDevice();

    return ( int )msg.wParam;
}

LRESULT CALLBACK WndProc( HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam )
{
    PAINTSTRUCT ps;
    HDC hdc;

    switch( message )
    {
        case WM_PAINT:
            hdc = BeginPaint( hWnd, &ps );
            EndPaint( hWnd, &ps );
            break;

        case WM_DESTROY:
            PostQuitMessage( 0 );
            break;

        default:
            return DefWindowProc( hWnd, message, wParam, lParam );
    }

    return 0;
}

HRESULT InitWindow( HINSTANCE hInstance, int nCmdShow )
{
    WNDCLASSEX wcex = { 0 };
    wcex.cbSize        = sizeof( WNDCLASSEX );
    wcex.style         = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc   = WndProc;
    wcex.cbClsExtra    = 0;
    wcex.cbWndExtra    = 0;
    wcex.hInstance     = hInstance;
    wcex.hCursor       = LoadCursor( NULL, IDC_ARROW );
    wcex.hbrBackground = ( HBRUSH )( COLOR_WINDOW + 1 );
    wcex.lpszMenuName  = NULL;
    wcex.lpszClassName = _T("WindowClass");
    if( !RegisterClassEx( &wcex ) )
        return E_FAIL;

    g_hInst = hInstance;
    RECT rc = { 0, 0, 640, 480 };
    AdjustWindowRect( &rc, WS_OVERLAPPEDWINDOW, FALSE );
    g_hWnd = CreateWindow( _T("WindowClass"), _T("Hello, World!"),
                           WS_OVERLAPPEDWINDOW,
                           CW_USEDEFAULT, CW_USEDEFAULT, rc.right - rc.left, rc.bottom - rc.top, NULL, NULL, hInstance,
                           NULL );
    if( !g_hWnd )
        return E_FAIL;

    ShowWindow( g_hWnd, nCmdShow );

    return S_OK;
}

HRESULT CompileShaderFromFile( LPCWSTR szFileName, LPCSTR szEntryPoint, LPCSTR szShaderModel, ID3DBlob** ppBlobOut )
{
    HRESULT hr = S_OK;

    DWORD dwShaderFlags = D3DCOMPILE_ENABLE_STRICTNESS;

    ID3DBlob* pErrorBlob = NULL;
    hr = D3DCompileFromFile( szFileName, NULL, NULL, szEntryPoint, szShaderModel, 
        dwShaderFlags, 0, ppBlobOut, &pErrorBlob );
    if( FAILED(hr) )
    {
        if( pErrorBlob ) pErrorBlob->lpVtbl->Release(pErrorBlob);
        return hr;
    }
    if( pErrorBlob ) pErrorBlob->lpVtbl->Release(pErrorBlob);

    return S_OK;
}

HRESULT InitDevice()
{
    HRESULT hr = S_OK;

    RECT rc;
    GetClientRect( g_hWnd, &rc );
    UINT width = rc.right - rc.left;
    UINT height = rc.bottom - rc.top;

    UINT createDeviceFlags = 0;

    D3D10_DRIVER_TYPE driverTypes[] =
    {
        D3D10_DRIVER_TYPE_HARDWARE,
        D3D10_DRIVER_TYPE_WARP,
        D3D10_DRIVER_TYPE_REFERENCE,
    };
    UINT numDriverTypes = ARRAYSIZE( driverTypes );

    DXGI_SWAP_CHAIN_DESC sd = { 0 };
    sd.BufferCount = 1;
    sd.BufferDesc.Width = width;
    sd.BufferDesc.Height = height;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = g_hWnd;
    sd.SampleDesc.Count = 1;
    sd.SampleDesc.Quality = 0;
    sd.Windowed = TRUE;

    for( UINT driverTypeIndex = 0; driverTypeIndex < numDriverTypes; driverTypeIndex++ )
    {
        g_driverType = driverTypes[driverTypeIndex];
        hr = D3D10CreateDeviceAndSwapChain( NULL, g_driverType, NULL, createDeviceFlags,
                                            D3D10_SDK_VERSION, &sd, &g_pSwapChain, &g_pd3dDevice );
        if( SUCCEEDED( hr ) )
            break;
    }
    if( FAILED( hr ) )
        return hr;

    ID3D10Texture2D* pBackBuffer = NULL;
    hr = g_pSwapChain->lpVtbl->GetBuffer( g_pSwapChain, 0, (REFIID)&IID_ID3D10Texture2D, ( LPVOID* )&pBackBuffer );
    if( FAILED( hr ) )
        return hr;

    hr = g_pd3dDevice->lpVtbl->CreateRenderTargetView(g_pd3dDevice, (ID3D10Resource*)pBackBuffer, NULL, &g_pRenderTargetView );
    pBackBuffer->lpVtbl->Release(pBackBuffer);
    if( FAILED( hr ) )
        return hr;

    g_pd3dDevice->lpVtbl->OMSetRenderTargets(g_pd3dDevice, 1, &g_pRenderTargetView, NULL );

    D3D10_VIEWPORT vp = { 0 };
    vp.Width    = width;
    vp.Height   = height;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    g_pd3dDevice->lpVtbl->RSSetViewports(g_pd3dDevice, 1, &vp );

    ID3DBlob* pVSBlob = NULL;
    hr = CompileShaderFromFile( L"hello.fx", "VS", "vs_4_0", &pVSBlob );
    if( FAILED( hr ) )
        return hr;

    hr = g_pd3dDevice->lpVtbl->CreateVertexShader(g_pd3dDevice, 
        pVSBlob->lpVtbl->GetBufferPointer(pVSBlob),
        pVSBlob->lpVtbl->GetBufferSize(pVSBlob), &g_pVertexShader );
    if( FAILED( hr ) )
    {
        pVSBlob->lpVtbl->Release(pVSBlob);
        return hr;
    }

    D3D10_INPUT_ELEMENT_DESC layout[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D10_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D10_INPUT_PER_VERTEX_DATA, 0 }
    };
    UINT numElements = ARRAYSIZE( layout );

    hr = g_pd3dDevice->lpVtbl->CreateInputLayout(g_pd3dDevice, layout, numElements, 
        pVSBlob->lpVtbl->GetBufferPointer(pVSBlob),
        pVSBlob->lpVtbl->GetBufferSize(pVSBlob), &g_pVertexLayout );
    pVSBlob->lpVtbl->Release(pVSBlob);
    if( FAILED( hr ) )
        return hr;

    g_pd3dDevice->lpVtbl->IASetInputLayout(g_pd3dDevice, g_pVertexLayout );

    ID3DBlob* pPSBlob = NULL;
    hr = CompileShaderFromFile( L"hello.fx", "PS", "ps_4_0", &pPSBlob );
    if( FAILED( hr ) )
        return hr;

    hr = g_pd3dDevice->lpVtbl->CreatePixelShader(g_pd3dDevice, 
        pPSBlob->lpVtbl->GetBufferPointer(pPSBlob), 
        pPSBlob->lpVtbl->GetBufferSize(pPSBlob), &g_pPixelShader );
    pPSBlob->lpVtbl->Release(pPSBlob);
    if( FAILED( hr ) )
        return hr;

    VERTEX vertices[] =
    {
        {   0.0f,  0.5f, 0.5f, 1.0f, 0.0f, 0.0f, 1.0f },
        {   0.5f, -0.5f, 0.5f, 0.0f, 1.0f, 0.0f, 1.0f },
        {  -0.5f, -0.5f, 0.5f, 0.0f, 0.0f, 1.0f, 1.0f },
    };
    D3D10_BUFFER_DESC bd = { 0 };
    bd.Usage          = D3D10_USAGE_DEFAULT;
    bd.ByteWidth      = sizeof( VERTEX ) * 3;
    bd.BindFlags      = D3D10_BIND_VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;
    bd.MiscFlags      = 0;
    D3D10_SUBRESOURCE_DATA InitData = { 0 };
    InitData.pSysMem = vertices;
    hr = g_pd3dDevice->lpVtbl->CreateBuffer(g_pd3dDevice, &bd, &InitData, &g_pVertexBuffer );
    if( FAILED( hr ) )
        return hr;

    UINT stride = sizeof( VERTEX );
    UINT offset = 0;
    g_pd3dDevice->lpVtbl->IASetVertexBuffers(g_pd3dDevice, 0, 1, &g_pVertexBuffer, &stride, &offset );

    g_pd3dDevice->lpVtbl->IASetPrimitiveTopology(g_pd3dDevice, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST );

    return S_OK;
}

void CleanupDevice()
{
    if( g_pd3dDevice ) g_pd3dDevice->lpVtbl->ClearState(g_pd3dDevice);

    if( g_pVertexBuffer ) g_pVertexBuffer->lpVtbl->Release(g_pVertexBuffer);
    if( g_pVertexLayout ) g_pVertexLayout->lpVtbl->Release(g_pVertexLayout);
    if( g_pVertexShader ) g_pVertexShader->lpVtbl->Release(g_pVertexShader);
    if( g_pPixelShader ) g_pPixelShader->lpVtbl->Release(g_pPixelShader);
    if( g_pRenderTargetView ) g_pRenderTargetView->lpVtbl->Release(g_pRenderTargetView);
    if( g_pSwapChain ) g_pSwapChain->lpVtbl->Release(g_pSwapChain);
    if( g_pd3dDevice ) g_pd3dDevice->lpVtbl->Release(g_pd3dDevice);
}

void Render()
{
    float ClearColor[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    g_pd3dDevice->lpVtbl->ClearRenderTargetView(g_pd3dDevice, g_pRenderTargetView, ClearColor );

    g_pd3dDevice->lpVtbl->VSSetShader(g_pd3dDevice, g_pVertexShader );
    g_pd3dDevice->lpVtbl->PSSetShader(g_pd3dDevice, g_pPixelShader );
    g_pd3dDevice->lpVtbl->Draw(g_pd3dDevice, 3, 0 );

    g_pSwapChain->lpVtbl->Present(g_pSwapChain, 0, 0 );
}
