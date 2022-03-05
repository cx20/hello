// forked from https://github.com/evilrat666/directx-d/blob/master/examples/2_d3d11_triangle/source/d3d11_triangle.d

import core.runtime;
import std.string : toStringz;
import std.utf : toUTF16z;
import core.stdc.string : memset;

import directx.win32;
import directx.d3d11;
import directx.d3dx11async;
import directx.d3dcompiler;

struct FLOAT3
{
    float x, y, z;
}

struct FLOAT4
{
    float x, y, z, w;
}

struct VERTEX
{
    FLOAT3 Pos;
    FLOAT4 Col;
}

HINSTANCE               g_hInst = null;
HWND                    g_hWnd = null;
D3D_DRIVER_TYPE         g_driverType = D3D_DRIVER_TYPE_NULL;
D3D_FEATURE_LEVEL       g_featureLevel = D3D_FEATURE_LEVEL_11_0;
ID3D11Device            g_pd3dDevice = null;
ID3D11DeviceContext     g_pImmediateContext = null;
IDXGISwapChain          g_pSwapChain = null;
ID3D11RenderTargetView  g_pRenderTargetView = null;
ID3D11VertexShader      g_pVertexShader = null;
ID3D11PixelShader       g_pPixelShader = null;
ID3D11InputLayout       g_pVertexLayout = null;
ID3D11Buffer            g_pVertexBuffer = null;

int myWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow )
{

    InitWindow( hInstance, nCmdShow );

    InitDevice();

    MSG msg;
    while( WM_QUIT != msg.message )
    {
        if( PeekMessage( &msg, null, 0, 0, PM_REMOVE ) )
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

    return cast( int )msg.wParam;
}


extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int result;

    import core.runtime;
    try
    {
        Runtime.initialize();
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);
        Runtime.terminate();
    }
    catch (Exception e)
    {
        result = 0;
    }

    return result;
}

HRESULT InitWindow( HINSTANCE hInstance, int nCmdShow )
{
    HINSTANCE hInst = GetModuleHandleA(null);
    WNDCLASS  wc;

    wc.lpszClassName = "DWndClass";
    wc.style         = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = &WndProc;
    wc.hInstance     = hInst;
    wc.hIcon         = LoadIcon(cast(HINSTANCE) null, IDI_APPLICATION);
    wc.hCursor       = LoadCursor(cast(HINSTANCE) null, IDC_CROSS);
    wc.hbrBackground = cast(HBRUSH) (COLOR_WINDOW + 1);
    wc.lpszMenuName  = null;
    wc.cbClsExtra    = wc.cbWndExtra = 0;
    auto a = RegisterClass(&wc);

    g_hWnd = CreateWindow("DWndClass", "Hello, World!", WS_THICKFRAME |
                         WS_MAXIMIZEBOX | WS_MINIMIZEBOX | WS_SYSMENU | WS_VISIBLE,
                         CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, HWND_DESKTOP,
                         cast(HMENU) null, hInst, null);
    RECT rc = { 0, 0, 640, 480 };
    AdjustWindowRect( &rc, WS_OVERLAPPEDWINDOW, FALSE );
    
    ShowWindow( g_hWnd, nCmdShow );

    return S_OK;
}

HRESULT CompileShaderFromFile( string szFileName, string szEntryPoint, string szShaderModel, ID3DBlob* ppBlobOut )
{
    HRESULT hr = S_OK;

    DWORD dwShaderFlags = D3DCOMPILE_ENABLE_STRICTNESS;

    ID3DBlob pErrorBlob;

    hr = D3DCompileFromFile ( toUTF16z(szFileName), null, null, toStringz(szEntryPoint), toStringz(szShaderModel),
        dwShaderFlags, 0, ppBlobOut, &pErrorBlob);

    if( FAILED(hr) )
    {
        if( pErrorBlob ) 
        {
            pErrorBlob.Release();
        }
        return hr;
    }
    if( pErrorBlob ) pErrorBlob.Release();

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

    D3D_DRIVER_TYPE[] driverTypes =
    [
        D3D_DRIVER_TYPE_HARDWARE,
        D3D_DRIVER_TYPE_WARP,
        D3D_DRIVER_TYPE_REFERENCE,
    ];
    UINT numDriverTypes = cast(UINT)driverTypes.length;

    D3D_FEATURE_LEVEL[] featureLevels =
    [
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    ];
    UINT numFeatureLevels = cast(UINT)featureLevels.length;

    DXGI_SWAP_CHAIN_DESC sd;
    memset( &sd, 0, DXGI_SWAP_CHAIN_DESC.sizeof );
    sd.BufferCount        = 1;
    sd.BufferDesc.Width   = width;
    sd.BufferDesc.Height  = height;
    sd.BufferDesc.Format  = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator   = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.BufferUsage        = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow       = g_hWnd;
    sd.SampleDesc.Count   = 1;
    sd.SampleDesc.Quality = 0;
    sd.Windowed = TRUE;

    for( UINT driverTypeIndex = 0; driverTypeIndex < numDriverTypes; driverTypeIndex++ )
    {
        g_driverType = driverTypes[driverTypeIndex];
        hr = D3D11CreateDeviceAndSwapChain( null, g_driverType, null, createDeviceFlags, featureLevels.ptr, numFeatureLevels,
                                            D3D11_SDK_VERSION, &sd, &g_pSwapChain, &g_pd3dDevice, &g_featureLevel, &g_pImmediateContext );
        if( SUCCEEDED( hr ) )
            break;
    }
    if( FAILED( hr ) )
        return hr;

    ID3D11Texture2D pBackBuffer;
    hr = g_pSwapChain.GetBuffer( 0, &IID_ID3D11Texture2D, cast( LPVOID* )&pBackBuffer );
    if( FAILED( hr ) )
        return hr;

    hr = g_pd3dDevice.CreateRenderTargetView( pBackBuffer, null, &g_pRenderTargetView );
    pBackBuffer.Release();
    if( FAILED( hr ) )
        return hr;

    g_pImmediateContext.OMSetRenderTargets( 1, &g_pRenderTargetView, null );

    D3D11_VIEWPORT vp;
    vp.Width = cast(FLOAT)width;
    vp.Height = cast(FLOAT)height;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    g_pImmediateContext.RSSetViewports( 1, &vp );

    ID3DBlob pVSBlob;
    hr = CompileShaderFromFile( "hello.fx" , "VS", "vs_4_0", &pVSBlob );
    if( FAILED( hr ) )
    {
        return hr;
    }

    hr = g_pd3dDevice.CreateVertexShader( pVSBlob.GetBufferPointer(), pVSBlob.GetBufferSize(), null, &g_pVertexShader );
    if( FAILED( hr ) )
    {    
        pVSBlob.Release();
        return hr;
    }

    D3D11_INPUT_ELEMENT_DESC[] layout =
    [
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 }
    ];
    UINT numElements =  cast(UINT)layout.length;

    hr = g_pd3dDevice.CreateInputLayout( layout.ptr, numElements, pVSBlob.GetBufferPointer(),
                                          pVSBlob.GetBufferSize(), &g_pVertexLayout );
    pVSBlob.Release();
    if( FAILED( hr ) )
        return hr;

    g_pImmediateContext.IASetInputLayout( g_pVertexLayout );

    ID3DBlob pPSBlob;
    hr = CompileShaderFromFile( "hello.fx", "PS", "ps_4_0", &pPSBlob );
    if( FAILED( hr ) )
    {
        return hr;
    }

    hr = g_pd3dDevice.CreatePixelShader( pPSBlob.GetBufferPointer(), pPSBlob.GetBufferSize(), null, &g_pPixelShader );
    pPSBlob.Release();
    if( FAILED( hr ) )
        return hr;

    VERTEX[3] vertices = 
    [
       { Pos: FLOAT3( 0.0f,  0.5f, 0.5f), Col: FLOAT4( 1.0f,  0.0f, 0.0f, 1.0f)},
       { Pos: FLOAT3( 0.5f, -0.5f, 0.5f), Col: FLOAT4( 0.0f,  1.0f, 0.0f, 1.0f)},
       { Pos: FLOAT3(-0.5f, -0.5f, 0.5f), Col: FLOAT4( 0.0f,  0.0f, 1.0f, 1.0f)}
    ];

    D3D11_BUFFER_DESC bd;
    memset( &bd, 0, D3D11_BUFFER_DESC.sizeof );
    bd.Usage          = D3D11_USAGE_DEFAULT;
    bd.ByteWidth      = (FLOAT3.sizeof + FLOAT4.sizeof) * 3;
    bd.BindFlags      = D3D11_BIND_VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;
    D3D11_SUBRESOURCE_DATA InitData;
    memset( &InitData, 0, D3D11_SUBRESOURCE_DATA.sizeof );
    InitData.pSysMem = vertices.ptr;
    hr = g_pd3dDevice.CreateBuffer( &bd, &InitData, &g_pVertexBuffer );

    UINT stride = FLOAT3.sizeof + FLOAT4.sizeof;
    UINT offset = 0;
    g_pImmediateContext.IASetVertexBuffers( 0, 1, &g_pVertexBuffer, &stride, &offset );

    g_pImmediateContext.IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );

    return S_OK;
}

void CleanupDevice()
{
    if( g_pImmediateContext ) g_pImmediateContext.ClearState();

    if( g_pVertexBuffer ) g_pVertexBuffer.Release();
    if( g_pVertexLayout ) g_pVertexLayout.Release();
    if( g_pVertexShader ) g_pVertexShader.Release();
    if( g_pPixelShader ) g_pPixelShader.Release();
    if( g_pRenderTargetView ) g_pRenderTargetView.Release();
    if( g_pSwapChain ) g_pSwapChain.Release();
    if( g_pImmediateContext ) g_pImmediateContext.Release();
    if( g_pd3dDevice ) g_pd3dDevice.Release();
}

extern(Windows)
LRESULT WndProc( HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam ) nothrow
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

void Render()
{
    float[4] ClearColor = [ 0.0f, 0.0, 0.0f, 1.0f ];
    g_pImmediateContext.ClearRenderTargetView( g_pRenderTargetView, ClearColor.ptr );

    g_pImmediateContext.VSSetShader( g_pVertexShader, null, 0 );
    g_pImmediateContext.PSSetShader( g_pPixelShader, null, 0 );
    g_pImmediateContext.Draw( 3, 0 );

    g_pSwapChain.Present( 0, 0 );
}
