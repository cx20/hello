#include <atlbase.h>
#include <atlwin.h>
#include <d3d11.h>
#include <d3dx11.h>
#include <d3dcompiler.h>
#include <xnamath.h>

struct VERTEX
{
    XMFLOAT3 Pos;
    XMFLOAT4 Color;
};

HRESULT CompileShaderFromFile( TCHAR* szFileName, LPCTSTR szEntryPoint, LPCTSTR szShaderModel, ID3DBlob** ppBlobOut );

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
    HRESULT InitDevice();
    VOID Cleanup();
    VOID Render();

private:
	D3D_DRIVER_TYPE         m_driverType;
	D3D_FEATURE_LEVEL       m_featureLevel;
	ID3D11Device*           m_pd3dDevice;
	ID3D11DeviceContext*    m_pImmediateContext;
	IDXGISwapChain*         m_pSwapChain;
	ID3D11RenderTargetView* m_pRenderTargetView;
	ID3D11VertexShader*     m_pVertexShader;
	ID3D11PixelShader*      m_pPixelShader;
	ID3D11InputLayout*      m_pVertexLayout;
	ID3D11Buffer*           m_pVertexBuffer;
};

CHelloWindow::CHelloWindow()
{
	m_driverType = D3D_DRIVER_TYPE_NULL;
	m_featureLevel = D3D_FEATURE_LEVEL_11_0;
	m_pd3dDevice = NULL;
	m_pImmediateContext = NULL;
	m_pSwapChain = NULL;
	m_pRenderTargetView = NULL;
	m_pVertexShader = NULL;
	m_pPixelShader = NULL;
	m_pVertexLayout = NULL;
	m_pVertexBuffer = NULL;
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

HRESULT CHelloWindow::InitDevice()
{
    HRESULT hr = S_OK;

    RECT rc;
    GetClientRect( &rc );
    UINT width = rc.right - rc.left;
    UINT height = rc.bottom - rc.top;

    UINT createDeviceFlags = 0;

    D3D_DRIVER_TYPE driverTypes[] =
    {
        D3D_DRIVER_TYPE_HARDWARE,
        D3D_DRIVER_TYPE_WARP,
        D3D_DRIVER_TYPE_REFERENCE,
    };
    UINT numDriverTypes = ARRAYSIZE( driverTypes );

    D3D_FEATURE_LEVEL featureLevels[] =
    {
        D3D_FEATURE_LEVEL_11_0,
    };
    UINT numFeatureLevels = ARRAYSIZE( featureLevels );

    DXGI_SWAP_CHAIN_DESC sd = { 0 };
    sd.BufferCount = 1;
    sd.BufferDesc.Width = width;
    sd.BufferDesc.Height = height;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = m_hWnd;
    sd.SampleDesc.Count = 1;
    sd.SampleDesc.Quality = 0;
    sd.Windowed = TRUE;

    for( UINT driverTypeIndex = 0; driverTypeIndex < numDriverTypes; driverTypeIndex++ )
    {
        m_driverType = driverTypes[driverTypeIndex];
        hr = D3D11CreateDeviceAndSwapChain( NULL, m_driverType, NULL, createDeviceFlags, featureLevels, numFeatureLevels,
                                            D3D11_SDK_VERSION, &sd, &m_pSwapChain, &m_pd3dDevice, &m_featureLevel, &m_pImmediateContext );
        if( SUCCEEDED( hr ) )
            break;
    }
    if( FAILED( hr ) )
        return hr;

    ID3D11Texture2D* pBackBuffer = NULL;
    hr = m_pSwapChain->GetBuffer( 0, __uuidof( ID3D11Texture2D ), ( LPVOID* )&pBackBuffer );
    if( FAILED( hr ) )
        return hr;

    hr = m_pd3dDevice->CreateRenderTargetView( pBackBuffer, NULL, &m_pRenderTargetView );
    pBackBuffer->Release();
    if( FAILED( hr ) )
        return hr;

    m_pImmediateContext->OMSetRenderTargets( 1, &m_pRenderTargetView, NULL );

    D3D11_VIEWPORT vp = { 0 };
    vp.Width    = (FLOAT)width;
    vp.Height   = (FLOAT)height;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    m_pImmediateContext->RSSetViewports( 1, &vp );

    ID3DBlob* pVSBlob = NULL;
    hr = CompileShaderFromFile( _T("hello.fx"), _T("VS"), _T("vs_4_0"), &pVSBlob );
    if( FAILED( hr ) )
        return hr;

    hr = m_pd3dDevice->CreateVertexShader( pVSBlob->GetBufferPointer(), pVSBlob->GetBufferSize(), NULL, &m_pVertexShader );
    if( FAILED( hr ) )
    {
        pVSBlob->Release();
        return hr;
    }

    D3D11_INPUT_ELEMENT_DESC layout[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 }
    };
    UINT numElements = ARRAYSIZE( layout );

    hr = m_pd3dDevice->CreateInputLayout( layout, numElements, pVSBlob->GetBufferPointer(),
                                          pVSBlob->GetBufferSize(), &m_pVertexLayout );
    pVSBlob->Release();
    if( FAILED( hr ) )
        return hr;

    m_pImmediateContext->IASetInputLayout( m_pVertexLayout );

    ID3DBlob* pPSBlob = NULL;
    hr = CompileShaderFromFile( _T("hello.fx"), _T("PS"), _T("ps_4_0"), &pPSBlob );
    if( FAILED( hr ) )
        return hr;

    hr = m_pd3dDevice->CreatePixelShader( pPSBlob->GetBufferPointer(), pPSBlob->GetBufferSize(), NULL, &m_pPixelShader );
    pPSBlob->Release();
    if( FAILED( hr ) )
        return hr;

    VERTEX vertices[] =
    {
        { XMFLOAT3(  0.0f,  0.5f, 0.5f ), XMFLOAT4(1.0f, 0.0f, 0.0f, 1.0f) },
        { XMFLOAT3(  0.5f, -0.5f, 0.5f ), XMFLOAT4(0.0f, 1.0f, 0.0f, 1.0f) },
        { XMFLOAT3( -0.5f, -0.5f, 0.5f ), XMFLOAT4(0.0f, 0.0f, 1.0f, 1.0f) },
    };
    D3D11_BUFFER_DESC bd = { 0 };
    bd.Usage          = D3D11_USAGE_DEFAULT;
    bd.ByteWidth      = sizeof( VERTEX ) * 3;
    bd.BindFlags      = D3D11_BIND_VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;
    D3D11_SUBRESOURCE_DATA InitData = { 0 };
    InitData.pSysMem = vertices;
    hr = m_pd3dDevice->CreateBuffer( &bd, &InitData, &m_pVertexBuffer );
    if( FAILED( hr ) )
        return hr;

    UINT stride = sizeof( VERTEX );
    UINT offset = 0;
    m_pImmediateContext->IASetVertexBuffers( 0, 1, &m_pVertexBuffer, &stride, &offset );

    m_pImmediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );

    return S_OK;
}

VOID CHelloWindow::Cleanup()
{
    if( m_pImmediateContext ) m_pImmediateContext->ClearState();

    if( m_pVertexBuffer ) m_pVertexBuffer->Release();
    if( m_pVertexLayout ) m_pVertexLayout->Release();
    if( m_pVertexShader ) m_pVertexShader->Release();
    if( m_pPixelShader ) m_pPixelShader->Release();
    if( m_pRenderTargetView ) m_pRenderTargetView->Release();
    if( m_pSwapChain ) m_pSwapChain->Release();
    if( m_pImmediateContext ) m_pImmediateContext->Release();
    if( m_pd3dDevice ) m_pd3dDevice->Release();
}

VOID CHelloWindow::Render()
{
    if (m_pd3dDevice == NULL) {
        return;
    }
    float ClearColor[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    m_pImmediateContext->ClearRenderTargetView( m_pRenderTargetView, ClearColor );

    m_pImmediateContext->VSSetShader( m_pVertexShader, NULL, 0 );
    m_pImmediateContext->PSSetShader( m_pPixelShader, NULL, 0 );
    m_pImmediateContext->Draw( 3, 0 );

    m_pSwapChain->Present( 0, 0 );
}

HRESULT CompileShaderFromFile( TCHAR* szFileName, LPCTSTR szEntryPoint, LPCTSTR szShaderModel, ID3DBlob** ppBlobOut )
{
    HRESULT hr = S_OK;

    DWORD dwShaderFlags = D3DCOMPILE_ENABLE_STRICTNESS;

    ID3DBlob* pErrorBlob;
    hr = D3DX11CompileFromFile( szFileName, NULL, NULL, szEntryPoint, szShaderModel, 
        dwShaderFlags, 0, NULL, ppBlobOut, &pErrorBlob, NULL );
    if( FAILED(hr) )
    {
        if( pErrorBlob ) pErrorBlob->Release();
        return hr;
    }
    if( pErrorBlob ) pErrorBlob->Release();

    return S_OK;
}

CComModule _Module;

int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);

    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    wnd.ResizeClient( 640, 480 );
    wnd.InitDevice();
    MSG msg;
    while( GetMessage( &msg, NULL, 0, 0 ) ){
        TranslateMessage( &msg );
        DispatchMessage( &msg );
    }

    _Module.Term();

    return (int)msg.wParam;
}