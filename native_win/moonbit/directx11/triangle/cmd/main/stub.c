#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>

typedef struct _VERTEX {
    FLOAT x;
    FLOAT y;
    FLOAT z;
    FLOAT r;
    FLOAT g;
    FLOAT b;
    FLOAT a;
} VERTEX;

static HWND g_hWnd = NULL;
static D3D_DRIVER_TYPE g_driverType = D3D_DRIVER_TYPE_NULL;
static D3D_FEATURE_LEVEL g_featureLevel = D3D_FEATURE_LEVEL_11_0;
static ID3D11Device *g_pd3dDevice = NULL;
static ID3D11DeviceContext *g_pImmediateContext = NULL;
static IDXGISwapChain *g_pSwapChain = NULL;
static ID3D11RenderTargetView *g_pRenderTargetView = NULL;
static ID3D11VertexShader *g_pVertexShader = NULL;
static ID3D11PixelShader *g_pPixelShader = NULL;
static ID3D11InputLayout *g_pVertexLayout = NULL;
static ID3D11Buffer *g_pVertexBuffer = NULL;

static LRESULT CALLBACK WindowProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam);
static HRESULT InitWindow(HINSTANCE hInstance);
static HRESULT InitDevice(void);
static HRESULT CompileShaderFromSource(const char *source, const char *entryPoint, const char *shaderModel, ID3DBlob **ppBlobOut);
static void CleanupDevice(void);
static void Render(void);

void run_directx11(void) {
    MSG msg;
    HINSTANCE hInstance = GetModuleHandleA(NULL);

    if (FAILED(InitWindow(hInstance))) {
        return;
    }

    if (FAILED(InitDevice())) {
        CleanupDevice();
        DestroyWindow(g_hWnd);
        g_hWnd = NULL;
        return;
    }

    ShowWindow(g_hWnd, SW_SHOWDEFAULT);
    UpdateWindow(g_hWnd);

    ZeroMemory(&msg, sizeof(msg));
    while (msg.message != WM_QUIT) {
        if (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageA(&msg);
        } else {
            Render();
        }
    }

    CleanupDevice();
    DestroyWindow(g_hWnd);
    g_hWnd = NULL;
}

static LRESULT CALLBACK WindowProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    (void)wParam;
    (void)lParam;

    switch (message) {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcA(hWnd, message, wParam, lParam);
    }
}

static HRESULT InitWindow(HINSTANCE hInstance) {
    WNDCLASSEXA wcex;
    RECT rc;

    ZeroMemory(&wcex, sizeof(wcex));
    wcex.cbSize = sizeof(wcex);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = WindowProc;
    wcex.hInstance = hInstance;
    wcex.hCursor = LoadCursorA(NULL, IDC_ARROW);
    wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wcex.lpszClassName = "helloWindow";

    if (!RegisterClassExA(&wcex)) {
        return E_FAIL;
    }

    rc.left = 0;
    rc.top = 0;
    rc.right = 640;
    rc.bottom = 480;
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);

    g_hWnd = CreateWindowExA(
        0,
        "helloWindow",
        "Hello, World!",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        rc.right - rc.left,
        rc.bottom - rc.top,
        NULL,
        NULL,
        hInstance,
        NULL
    );

    if (g_hWnd == NULL) {
        return E_FAIL;
    }

    return S_OK;
}

static HRESULT CompileShaderFromSource(const char *source, const char *entryPoint, const char *shaderModel, ID3DBlob **ppBlobOut) {
    UINT shaderFlags = D3DCOMPILE_ENABLE_STRICTNESS;
    ID3DBlob *pErrorBlob = NULL;
    HRESULT hr;

    hr = D3DCompile(
        source,
        lstrlenA(source),
        NULL,
        NULL,
        NULL,
        entryPoint,
        shaderModel,
        shaderFlags,
        0,
        ppBlobOut,
        &pErrorBlob
    );

    if (pErrorBlob != NULL) {
        pErrorBlob->lpVtbl->Release(pErrorBlob);
    }

    return hr;
}

static HRESULT InitDevice(void) {
    RECT rc;
    UINT width;
    UINT height;
    UINT createDeviceFlags = 0;
    D3D_DRIVER_TYPE driverTypes[] = {
        D3D_DRIVER_TYPE_HARDWARE,
        D3D_DRIVER_TYPE_WARP,
        D3D_DRIVER_TYPE_REFERENCE,
    };
    D3D_FEATURE_LEVEL featureLevels[] = {
        D3D_FEATURE_LEVEL_11_0,
    };
    DXGI_SWAP_CHAIN_DESC sd;
    HRESULT hr = E_FAIL;
    UINT i;
    ID3D11Texture2D *pBackBuffer = NULL;
    D3D11_VIEWPORT vp;
    ID3DBlob *pVSBlob = NULL;
    ID3DBlob *pPSBlob = NULL;
    D3D11_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };
    VERTEX vertices[] = {
        { 0.0f, 0.5f, 0.5f, 1.0f, 0.0f, 0.0f, 1.0f },
        { 0.5f, -0.5f, 0.5f, 0.0f, 1.0f, 0.0f, 1.0f },
        { -0.5f, -0.5f, 0.5f, 0.0f, 0.0f, 1.0f, 1.0f },
    };
    D3D11_BUFFER_DESC bd;
    D3D11_SUBRESOURCE_DATA initData;
    UINT stride = sizeof(VERTEX);
    UINT offset = 0;
    const char *vsSource =
        "struct VS_IN { float3 pos : POSITION; float4 col : COLOR; };"
        "struct PS_IN { float4 pos : SV_POSITION; float4 col : COLOR; };"
        "PS_IN VSMain(VS_IN input) {"
        "  PS_IN output;"
        "  output.pos = float4(input.pos, 1.0);"
        "  output.col = input.col;"
        "  return output;"
        "}";
    const char *psSource =
        "struct PS_IN { float4 pos : SV_POSITION; float4 col : COLOR; };"
        "float4 PSMain(PS_IN input) : SV_Target {"
        "  return input.col;"
        "}";

    GetClientRect(g_hWnd, &rc);
    width = (UINT)(rc.right - rc.left);
    height = (UINT)(rc.bottom - rc.top);

    ZeroMemory(&sd, sizeof(sd));
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

    for (i = 0; i < sizeof(driverTypes) / sizeof(driverTypes[0]); i++) {
        g_driverType = driverTypes[i];
        hr = D3D11CreateDeviceAndSwapChain(
            NULL,
            g_driverType,
            NULL,
            createDeviceFlags,
            featureLevels,
            (UINT)(sizeof(featureLevels) / sizeof(featureLevels[0])),
            D3D11_SDK_VERSION,
            &sd,
            &g_pSwapChain,
            &g_pd3dDevice,
            &g_featureLevel,
            &g_pImmediateContext
        );
        if (SUCCEEDED(hr)) {
            break;
        }
    }
    if (FAILED(hr)) {
        return hr;
    }

    hr = g_pSwapChain->lpVtbl->GetBuffer(g_pSwapChain, 0, (REFIID)&IID_ID3D11Texture2D, (void **)&pBackBuffer);
    if (FAILED(hr)) {
        return hr;
    }

    hr = g_pd3dDevice->lpVtbl->CreateRenderTargetView(g_pd3dDevice, (ID3D11Resource *)pBackBuffer, NULL, &g_pRenderTargetView);
    pBackBuffer->lpVtbl->Release(pBackBuffer);
    pBackBuffer = NULL;
    if (FAILED(hr)) {
        return hr;
    }

    g_pImmediateContext->lpVtbl->OMSetRenderTargets(g_pImmediateContext, 1, &g_pRenderTargetView, NULL);

    ZeroMemory(&vp, sizeof(vp));
    vp.Width = (FLOAT)width;
    vp.Height = (FLOAT)height;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    g_pImmediateContext->lpVtbl->RSSetViewports(g_pImmediateContext, 1, &vp);

    hr = CompileShaderFromSource(vsSource, "VSMain", "vs_4_0", &pVSBlob);
    if (FAILED(hr)) {
        return hr;
    }

    hr = g_pd3dDevice->lpVtbl->CreateVertexShader(
        g_pd3dDevice,
        pVSBlob->lpVtbl->GetBufferPointer(pVSBlob),
        pVSBlob->lpVtbl->GetBufferSize(pVSBlob),
        NULL,
        &g_pVertexShader
    );
    if (FAILED(hr)) {
        pVSBlob->lpVtbl->Release(pVSBlob);
        return hr;
    }

    hr = g_pd3dDevice->lpVtbl->CreateInputLayout(
        g_pd3dDevice,
        layout,
        (UINT)(sizeof(layout) / sizeof(layout[0])),
        pVSBlob->lpVtbl->GetBufferPointer(pVSBlob),
        pVSBlob->lpVtbl->GetBufferSize(pVSBlob),
        &g_pVertexLayout
    );
    pVSBlob->lpVtbl->Release(pVSBlob);
    pVSBlob = NULL;
    if (FAILED(hr)) {
        return hr;
    }

    g_pImmediateContext->lpVtbl->IASetInputLayout(g_pImmediateContext, g_pVertexLayout);

    hr = CompileShaderFromSource(psSource, "PSMain", "ps_4_0", &pPSBlob);
    if (FAILED(hr)) {
        return hr;
    }

    hr = g_pd3dDevice->lpVtbl->CreatePixelShader(
        g_pd3dDevice,
        pPSBlob->lpVtbl->GetBufferPointer(pPSBlob),
        pPSBlob->lpVtbl->GetBufferSize(pPSBlob),
        NULL,
        &g_pPixelShader
    );
    pPSBlob->lpVtbl->Release(pPSBlob);
    pPSBlob = NULL;
    if (FAILED(hr)) {
        return hr;
    }

    ZeroMemory(&bd, sizeof(bd));
    bd.Usage = D3D11_USAGE_DEFAULT;
    bd.ByteWidth = (UINT)sizeof(vertices);
    bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bd.CPUAccessFlags = 0;

    ZeroMemory(&initData, sizeof(initData));
    initData.pSysMem = vertices;

    hr = g_pd3dDevice->lpVtbl->CreateBuffer(g_pd3dDevice, &bd, &initData, &g_pVertexBuffer);
    if (FAILED(hr)) {
        return hr;
    }

    g_pImmediateContext->lpVtbl->IASetVertexBuffers(g_pImmediateContext, 0, 1, &g_pVertexBuffer, &stride, &offset);
    g_pImmediateContext->lpVtbl->IASetPrimitiveTopology(g_pImmediateContext, D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    return S_OK;
}

static void CleanupDevice(void) {
    if (g_pImmediateContext != NULL) {
        g_pImmediateContext->lpVtbl->ClearState(g_pImmediateContext);
    }

    if (g_pVertexBuffer != NULL) {
        g_pVertexBuffer->lpVtbl->Release(g_pVertexBuffer);
        g_pVertexBuffer = NULL;
    }
    if (g_pVertexLayout != NULL) {
        g_pVertexLayout->lpVtbl->Release(g_pVertexLayout);
        g_pVertexLayout = NULL;
    }
    if (g_pVertexShader != NULL) {
        g_pVertexShader->lpVtbl->Release(g_pVertexShader);
        g_pVertexShader = NULL;
    }
    if (g_pPixelShader != NULL) {
        g_pPixelShader->lpVtbl->Release(g_pPixelShader);
        g_pPixelShader = NULL;
    }
    if (g_pRenderTargetView != NULL) {
        g_pRenderTargetView->lpVtbl->Release(g_pRenderTargetView);
        g_pRenderTargetView = NULL;
    }
    if (g_pSwapChain != NULL) {
        g_pSwapChain->lpVtbl->Release(g_pSwapChain);
        g_pSwapChain = NULL;
    }
    if (g_pImmediateContext != NULL) {
        g_pImmediateContext->lpVtbl->Release(g_pImmediateContext);
        g_pImmediateContext = NULL;
    }
    if (g_pd3dDevice != NULL) {
        g_pd3dDevice->lpVtbl->Release(g_pd3dDevice);
        g_pd3dDevice = NULL;
    }
}

static void Render(void) {
    FLOAT clearColor[4] = { 1.0f, 1.0f, 1.0f, 1.0f };

    if (g_pImmediateContext == NULL || g_pRenderTargetView == NULL) {
        return;
    }

    g_pImmediateContext->lpVtbl->ClearRenderTargetView(g_pImmediateContext, g_pRenderTargetView, clearColor);
    g_pImmediateContext->lpVtbl->VSSetShader(g_pImmediateContext, g_pVertexShader, NULL, 0);
    g_pImmediateContext->lpVtbl->PSSetShader(g_pImmediateContext, g_pPixelShader, NULL, 0);
    g_pImmediateContext->lpVtbl->Draw(g_pImmediateContext, 3, 0);

    g_pSwapChain->lpVtbl->Present(g_pSwapChain, 0, 0);
}
