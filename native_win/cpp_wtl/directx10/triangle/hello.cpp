#include <atlbase.h>
#include <atlapp.h>
#include <atlcrack.h>
#include <d3d10.h>
#include <d3dx10.h>

struct VERTEX
{
    D3DXVECTOR3 Pos;
    D3DXVECTOR4 Color;
};

class CHelloWindow : public CWindowImpl<CHelloWindow>
{
public:
    CHelloWindow();

    BEGIN_MSG_MAP( CHelloWindow )
        MSG_WM_PAINT   ( OnPaint   )
        MSG_WM_DESTROY ( OnDestroy )
    END_MSG_MAP()
 
    void OnPaint( HDC hDC );
    void OnDestroy();
    HRESULT InitDevice();
    VOID Cleanup();
    VOID Render();

private:
    D3D10_DRIVER_TYPE       m_driverType;
    ID3D10Device*           m_pd3dDevice;
    IDXGISwapChain*         m_pSwapChain;
    ID3D10RenderTargetView* m_pRenderTargetView;
    ID3D10Effect*           m_pEffect;
    ID3D10EffectTechnique*  m_pTechnique;
    ID3D10InputLayout*      m_pVertexLayout;
    ID3D10Buffer*           m_pVertexBuffer;
};

CHelloWindow::CHelloWindow()
{
    m_driverType = D3D10_DRIVER_TYPE_NULL;
    m_pd3dDevice = NULL;
    m_pSwapChain = NULL;
    m_pRenderTargetView = NULL;
    m_pEffect = NULL;
    m_pTechnique = NULL;
    m_pVertexLayout = NULL;
    m_pVertexBuffer = NULL;
}

void CHelloWindow::OnPaint( HDC hDC )
{
    Render();
}
void CHelloWindow::OnDestroy()
{
    Cleanup();
    PostQuitMessage( 0 );
}

HRESULT CHelloWindow::InitDevice()
{
    HRESULT hr = S_OK;

    RECT rc;
    GetClientRect( &rc );
    UINT width = rc.right - rc.left;
    UINT height = rc.bottom - rc.top;

    UINT createDeviceFlags = 0;

    D3D10_DRIVER_TYPE driverTypes[] =
    {
        D3D10_DRIVER_TYPE_HARDWARE,
        D3D10_DRIVER_TYPE_REFERENCE,
    };
    UINT numDriverTypes = sizeof( driverTypes ) / sizeof( driverTypes[0] );

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
        hr = D3D10CreateDeviceAndSwapChain( NULL, m_driverType, NULL, createDeviceFlags,
                                            D3D10_SDK_VERSION, &sd, &m_pSwapChain, &m_pd3dDevice );
        if( SUCCEEDED( hr ) )
            break;
    }
    if( FAILED( hr ) )
        return hr;

    ID3D10Texture2D* pBuffer;
    hr = m_pSwapChain->GetBuffer( 0, __uuidof( ID3D10Texture2D ), ( LPVOID* )&pBuffer );
    if( FAILED( hr ) )
        return hr;

    hr = m_pd3dDevice->CreateRenderTargetView( pBuffer, NULL, &m_pRenderTargetView );
    pBuffer->Release();
    if( FAILED( hr ) )
        return hr;

    m_pd3dDevice->OMSetRenderTargets( 1, &m_pRenderTargetView, NULL );

    D3D10_VIEWPORT vp = { 0 };
    vp.Width    = width;
    vp.Height   = height;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    m_pd3dDevice->RSSetViewports( 1, &vp );

    DWORD dwShaderFlags = D3D10_SHADER_ENABLE_STRICTNESS;
    hr = D3DX10CreateEffectFromFile( _T("hello.fx"), NULL, NULL, _T("fx_4_0"), dwShaderFlags, 0,
                                         m_pd3dDevice, NULL, NULL, &m_pEffect, NULL, NULL );
    if( FAILED( hr ) )
        return hr;

    m_pTechnique = m_pEffect->GetTechniqueByName( "Render" );

    D3D10_INPUT_ELEMENT_DESC layout[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D10_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D10_INPUT_PER_VERTEX_DATA, 0 }
    };
    UINT numElements = sizeof( layout ) / sizeof( layout[0] );

    D3D10_PASS_DESC PassDesc;
    m_pTechnique->GetPassByIndex( 0 )->GetDesc( &PassDesc );
    hr = m_pd3dDevice->CreateInputLayout( layout, numElements, PassDesc.pIAInputSignature,
                                          PassDesc.IAInputSignatureSize, &m_pVertexLayout );
    if( FAILED( hr ) )
        return hr;

    m_pd3dDevice->IASetInputLayout( m_pVertexLayout );

    VERTEX vertices[] =
    {
        { D3DXVECTOR3(  0.0f,  0.5f, 0.5f ), D3DXVECTOR4(1.0f, 0.0f, 0.0f, 1.0f) },
        { D3DXVECTOR3(  0.5f, -0.5f, 0.5f ), D3DXVECTOR4(0.0f, 1.0f, 0.0f, 1.0f) },
        { D3DXVECTOR3( -0.5f, -0.5f, 0.5f ), D3DXVECTOR4(0.0f, 0.0f, 1.0f, 1.0f) },
    };
    D3D10_BUFFER_DESC bd = { 0 };
    bd.Usage          = D3D10_USAGE_DEFAULT;
    bd.ByteWidth      = sizeof( VERTEX ) * 3;
    bd.BindFlags      = D3D10_BIND_VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;
    bd.MiscFlags      = 0;
    D3D10_SUBRESOURCE_DATA InitData;
    InitData.pSysMem = vertices;
    hr = m_pd3dDevice->CreateBuffer( &bd, &InitData, &m_pVertexBuffer );
    if( FAILED( hr ) )
        return hr;

    UINT stride = sizeof( VERTEX );
    UINT offset = 0;
    m_pd3dDevice->IASetVertexBuffers( 0, 1, &m_pVertexBuffer, &stride, &offset );
    m_pd3dDevice->IASetPrimitiveTopology( D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST );

    return S_OK;
}

VOID CHelloWindow::Cleanup()
{
    if( m_pd3dDevice ) m_pd3dDevice->ClearState();
    if( m_pVertexBuffer ) m_pVertexBuffer->Release();
    if( m_pVertexLayout ) m_pVertexLayout->Release();
    if( m_pEffect ) m_pEffect->Release();
    if( m_pRenderTargetView ) m_pRenderTargetView->Release();
    if( m_pSwapChain ) m_pSwapChain->Release();
    if( m_pd3dDevice ) m_pd3dDevice->Release();
}
 
VOID CHelloWindow::Render()
{
    if (m_pd3dDevice == NULL) {
        return;
    }
    float ClearColor[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    m_pd3dDevice->ClearRenderTargetView( m_pRenderTargetView, ClearColor );

    D3D10_TECHNIQUE_DESC techDesc;
    m_pTechnique->GetDesc( &techDesc );
    for( UINT p = 0; p < techDesc.Passes; ++p )
    {
        m_pTechnique->GetPassByIndex( p )->Apply( 0 );
        m_pd3dDevice->Draw( 3, 0 );
    }

    m_pSwapChain->Present( 0, 0 );
}

CAppModule _Module;
 
int APIENTRY _tWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow )
{
    _Module.Init(NULL, hInstance);
 
    CMessageLoop theLoop;
    _Module.AddMessageLoop(&theLoop);
 
    CHelloWindow wnd;
    wnd.Create( NULL, CWindow::rcDefault, _T("Hello, World!"), WS_OVERLAPPEDWINDOW | WS_VISIBLE );
    wnd.ResizeClient( 640, 480 );
    wnd.InitDevice();
    int nRet = theLoop.Run();
 
    _Module.RemoveMessageLoop();
    _Module.Term();
 
    return nRet;
}