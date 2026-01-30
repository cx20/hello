import core.runtime;
import std.string : toStringz;
import core.stdc.string : memset;

import directx.win32;
import directx.d3d10;
import directx.d3dcompiler;

// Function pointer type for D3D10CreateDeviceAndSwapChain
alias D3D10CreateDeviceAndSwapChainFunc = extern(Windows) HRESULT function(
    void* pAdapter,
    int DriverType,
    void* Software,
    UINT Flags,
    UINT SDKVersion,
    void* pSwapChainDesc,    // DXGI_SWAP_CHAIN_DESC*
    void** ppSwapChain,      // IDXGISwapChain**
    void** ppDevice          // ID3D10Device**
);

// VTable function pointer types for ID3D10Device methods
alias IASetInputLayoutFunc = extern(Windows) void function(void* pThis, void* pInputLayout);
alias IASetVertexBuffersFunc = extern(Windows) void function(void* pThis, UINT StartSlot, UINT NumBuffers, void** ppVertexBuffers, UINT* pStrides, UINT* pOffsets);
alias IASetPrimitiveTopologyFunc = extern(Windows) void function(void* pThis, int Topology);
alias VSSetShaderFunc = extern(Windows) void function(void* pThis, void* pVertexShader);
alias PSSetShaderFunc = extern(Windows) void function(void* pThis, void* pPixelShader);
alias DrawFunc = extern(Windows) void function(void* pThis, UINT VertexCount, UINT StartVertexLocation);
alias ClearRenderTargetViewFunc = extern(Windows) void function(void* pThis, void* pRenderTargetView, const float* ColorRGBA);
alias ClearStateFunc = extern(Windows) void function(void* pThis);
alias OMSetRenderTargetsFunc = extern(Windows) void function(void* pThis, UINT NumViews, void** ppRenderTargetViews, void* pDepthStencilView);
alias RSSetViewportsFunc = extern(Windows) void function(void* pThis, UINT NumViewports, void* pViewports);

// Helper to get VTable function
T getVTableFunc(T)(void* obj, size_t index)
{
    void** vTable = *cast(void***)obj;
    return cast(T)vTable[index];
}

// Dynamically loaded function
__gshared D3D10CreateDeviceAndSwapChainFunc g_D3D10CreateDeviceAndSwapChain;

// Load D3D10.dll and get function pointer
bool LoadD3D10()
{
    import core.sys.windows.winbase : LoadLibraryA, GetProcAddress;
    
    auto hD3D10 = LoadLibraryA("d3d10.dll");
    if (hD3D10 is null)
    {
        return false;
    }
    
    g_D3D10CreateDeviceAndSwapChain = cast(D3D10CreateDeviceAndSwapChainFunc)
        GetProcAddress(hD3D10, "D3D10CreateDeviceAndSwapChain");
    
    if (g_D3D10CreateDeviceAndSwapChain is null)
    {
        return false;
    }
    
    return true;
}

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
D3D10_DRIVER_TYPE       g_driverType = D3D10_DRIVER_TYPE_NULL;
ID3D10Device            g_pd3dDevice = null;
IDXGISwapChain          g_pSwapChain = null;
ID3D10RenderTargetView  g_pRenderTargetView = null;
ID3D10VertexShader      g_pVertexShader = null;
ID3D10PixelShader       g_pPixelShader = null;
ID3D10InputLayout       g_pVertexLayout = null;
ID3D10Buffer            g_pVertexBuffer = null;

int myWinMain( HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow )
{
    HRESULT hr = InitWindow( hInstance, nCmdShow );
    if( FAILED(hr) )
    {
        return -1;
    }

    hr = InitDevice();
    if( FAILED(hr) )
    {
        return -1;
    }

    MSG msg;
    memset(&msg, 0, MSG.sizeof);
    
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

// Windows entry point
extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int result;

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
    RegisterClass(&wc);

    g_hWnd = CreateWindow("DWndClass", "Hello, World!", WS_THICKFRAME |
                         WS_MAXIMIZEBOX | WS_MINIMIZEBOX | WS_SYSMENU | WS_VISIBLE,
                         CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, HWND_DESKTOP,
                         cast(HMENU) null, hInst, null);
    
    if (g_hWnd is null)
    {
        return E_FAIL;
    }
    
    RECT rc = { 0, 0, 640, 480 };
    AdjustWindowRect( &rc, WS_OVERLAPPEDWINDOW, FALSE );
    
    ShowWindow( g_hWnd, nCmdShow );

    return S_OK;
}

HRESULT CompileShaderFromFile( string szFileName, string szEntryPoint, string szShaderModel, ID3DBlob* ppBlobOut )
{
    import std.file : read, exists;
    
    HRESULT hr = S_OK;

    DWORD dwShaderFlags = D3DCOMPILE_ENABLE_STRICTNESS;

    ID3DBlob pErrorBlob;

    // Check if file exists
    if (!exists(szFileName))
    {
        return E_FAIL;
    }

    // Read shader file manually
    ubyte[] shaderSource;
    try
    {
        shaderSource = cast(ubyte[])read(szFileName);
    }
    catch (Exception e)
    {
        return E_FAIL;
    }

    // Use D3DCompile instead of D3DCompileFromFile
    hr = D3DCompile( shaderSource.ptr, shaderSource.length, toStringz(szFileName), null, null, 
        toStringz(szEntryPoint), toStringz(szShaderModel),
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

    // Load D3D10.dll dynamically
    if (!LoadD3D10())
    {
        return E_FAIL;
    }

    RECT rc;
    GetClientRect( g_hWnd, &rc );
    UINT width = rc.right - rc.left;
    UINT height = rc.bottom - rc.top;

    UINT createDeviceFlags = 0;

    int[] driverTypes =
    [
        D3D10_DRIVER_TYPE_HARDWARE,
        D3D10_DRIVER_TYPE_WARP,
        D3D10_DRIVER_TYPE_REFERENCE,
    ];
    UINT numDriverTypes = cast(UINT)driverTypes.length;

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
        auto driverType = driverTypes[driverTypeIndex];
        
        hr = g_D3D10CreateDeviceAndSwapChain( 
            null, 
            driverType, 
            null, 
            createDeviceFlags,
            D3D10_SDK_VERSION, 
            cast(void*)&sd, 
            cast(void**)&g_pSwapChain, 
            cast(void**)&g_pd3dDevice 
        );
        
        if( SUCCEEDED( hr ) )
            break;
    }
    if( FAILED( hr ) )
        return hr;

    ID3D10Texture2D pBackBuffer;
    hr = g_pSwapChain.GetBuffer( 0, &IID_ID3D10Texture2D, cast( void** )&pBackBuffer );
    if( FAILED( hr ) )
        return hr;

    hr = g_pd3dDevice.CreateRenderTargetView( pBackBuffer, null, &g_pRenderTargetView );
    pBackBuffer.Release();
    if( FAILED( hr ) )
        return hr;

    // Use VTable to call OMSetRenderTargets (#24)
    void* pRTV = cast(void*)g_pRenderTargetView;
    auto omSetRenderTargets = getVTableFunc!OMSetRenderTargetsFunc(cast(void*)g_pd3dDevice, 24);
    omSetRenderTargets(cast(void*)g_pd3dDevice, 1, &pRTV, null);

    // D3D10_VIEWPORT uses UINT for Width/Height
    D3D10_VIEWPORT vp;
    vp.Width = width;
    vp.Height = height;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    
    // Use VTable to call RSSetViewports (#30)
    auto rsSetViewports = getVTableFunc!RSSetViewportsFunc(cast(void*)g_pd3dDevice, 30);
    rsSetViewports(cast(void*)g_pd3dDevice, 1, &vp);

    ID3DBlob pVSBlob;
    hr = CompileShaderFromFile( "hello.fx" , "VS", "vs_4_0", &pVSBlob );
    if( FAILED( hr ) )
        return hr;

    hr = g_pd3dDevice.CreateVertexShader( pVSBlob.GetBufferPointer(), pVSBlob.GetBufferSize(), &g_pVertexShader );
    if( FAILED( hr ) )
    {    
        pVSBlob.Release();
        return hr;
    }

    D3D10_INPUT_ELEMENT_DESC[] layout =
    [
        D3D10_INPUT_ELEMENT_DESC( "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D10_INPUT_PER_VERTEX_DATA, 0 ),
        D3D10_INPUT_ELEMENT_DESC( "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D10_INPUT_PER_VERTEX_DATA, 0 )
    ];
    UINT numElements = cast(UINT)layout.length;

    hr = g_pd3dDevice.CreateInputLayout( layout.ptr, numElements, pVSBlob.GetBufferPointer(),
                                          pVSBlob.GetBufferSize(), &g_pVertexLayout );
    pVSBlob.Release();
    if( FAILED( hr ) )
        return hr;

    // Use VTable to call IASetInputLayout (#11)
    auto iaSetInputLayout = getVTableFunc!IASetInputLayoutFunc(cast(void*)g_pd3dDevice, 11);
    iaSetInputLayout(cast(void*)g_pd3dDevice, cast(void*)g_pVertexLayout);

    ID3DBlob pPSBlob;
    hr = CompileShaderFromFile( "hello.fx", "PS", "ps_4_0", &pPSBlob );
    if( FAILED( hr ) )
        return hr;

    hr = g_pd3dDevice.CreatePixelShader( pPSBlob.GetBufferPointer(), pPSBlob.GetBufferSize(), &g_pPixelShader );
    pPSBlob.Release();
    if( FAILED( hr ) )
        return hr;

    VERTEX[3] vertices = 
    [
       { Pos: FLOAT3( 0.0f,  0.5f, 0.5f), Col: FLOAT4( 1.0f,  0.0f, 0.0f, 1.0f)},
       { Pos: FLOAT3( 0.5f, -0.5f, 0.5f), Col: FLOAT4( 0.0f,  1.0f, 0.0f, 1.0f)},
       { Pos: FLOAT3(-0.5f, -0.5f, 0.5f), Col: FLOAT4( 0.0f,  0.0f, 1.0f, 1.0f)}
    ];

    D3D10_BUFFER_DESC bd;
    memset( &bd, 0, D3D10_BUFFER_DESC.sizeof );
    bd.Usage          = D3D10_USAGE_DEFAULT;
    bd.ByteWidth      = (FLOAT3.sizeof + FLOAT4.sizeof) * 3;
    bd.BindFlags      = D3D10_BIND_VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;
    bd.MiscFlags      = 0;
    D3D10_SUBRESOURCE_DATA InitData;
    memset( &InitData, 0, D3D10_SUBRESOURCE_DATA.sizeof );
    InitData.pSysMem = vertices.ptr;
    hr = g_pd3dDevice.CreateBuffer( &bd, &InitData, &g_pVertexBuffer );
    if( FAILED( hr ) )
        return hr;

    UINT stride = FLOAT3.sizeof + FLOAT4.sizeof;
    UINT offset = 0;
    
    // Use VTable to call IASetVertexBuffers (#12)
    void* pVB = cast(void*)g_pVertexBuffer;
    auto iaSetVertexBuffers = getVTableFunc!IASetVertexBuffersFunc(cast(void*)g_pd3dDevice, 12);
    iaSetVertexBuffers(cast(void*)g_pd3dDevice, 0, 1, &pVB, &stride, &offset);

    // Use VTable to call IASetPrimitiveTopology (#18)
    auto iaSetPrimitiveTopology = getVTableFunc!IASetPrimitiveTopologyFunc(cast(void*)g_pd3dDevice, 18);
    iaSetPrimitiveTopology(cast(void*)g_pd3dDevice, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    return S_OK;
}

void CleanupDevice()
{
    // In D3D10, ClearState is called on the device directly
    // Use VTable to call ClearState (#69)
    if( g_pd3dDevice )
    {
        auto clearState = getVTableFunc!ClearStateFunc(cast(void*)g_pd3dDevice, 69);
        clearState(cast(void*)g_pd3dDevice);
    }

    if( g_pVertexBuffer ) g_pVertexBuffer.Release();
    if( g_pVertexLayout ) g_pVertexLayout.Release();
    if( g_pVertexShader ) g_pVertexShader.Release();
    if( g_pPixelShader ) g_pPixelShader.Release();
    if( g_pRenderTargetView ) g_pRenderTargetView.Release();
    if( g_pSwapChain ) g_pSwapChain.Release();
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
    // Use static array directly (not pointer) for ClearRenderTargetView
    float[4] ClearColor = [ 1.0f, 1.0f, 1.0f, 1.0f ];
    
    // Use VTable to call ClearRenderTargetView (#35)
    auto clearRTV = getVTableFunc!ClearRenderTargetViewFunc(cast(void*)g_pd3dDevice, 35);
    clearRTV(cast(void*)g_pd3dDevice, cast(void*)g_pRenderTargetView, ClearColor.ptr);

    // Use VTable to call VSSetShader (#7)
    auto vsSetShader = getVTableFunc!VSSetShaderFunc(cast(void*)g_pd3dDevice, 7);
    vsSetShader(cast(void*)g_pd3dDevice, cast(void*)g_pVertexShader);
    
    // Use VTable to call PSSetShader (#5)
    auto psSetShader = getVTableFunc!PSSetShaderFunc(cast(void*)g_pd3dDevice, 5);
    psSetShader(cast(void*)g_pd3dDevice, cast(void*)g_pPixelShader);
    
    // Use VTable to call Draw (#9)
    auto draw = getVTableFunc!DrawFunc(cast(void*)g_pd3dDevice, 9);
    draw(cast(void*)g_pd3dDevice, 3, 0);

    g_pSwapChain.Present( 0, 0 );
}
