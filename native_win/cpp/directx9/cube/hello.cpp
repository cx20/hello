#include <d3d9.h>
#include <d3dx9.h>

LPDIRECT3D9             g_pD3D = NULL;
LPDIRECT3DDEVICE9       g_pd3dDevice = NULL;
LPDIRECT3DVERTEXBUFFER9 g_pVB = NULL;
LPDIRECT3DINDEXBUFFER9  g_pIB = NULL;

struct CUSTOMVERTEX
{
    float x, y, z;
    DWORD color;
};

// Cube data
//             1.0 y 
//              ^  -1.0 
//              | / z
//              |/       x
// -1.0 -----------------> +1.0
//            / |
//      +1.0 /  |
//           -1.0
// 
//         [7]------[6]
//        / |      / |
//      [3]------[2] |
//       |  |     |  |
//       | [4]----|-[5]
//       |/       |/
//      [0]------[1]
//
CUSTOMVERTEX g_Vertices[] =
{
    // Front face
    { 0.5f, -0.5f,  0.5f, 0xffff0000}, // v0
    { 0.5f, -0.5f,  0.5f, 0xffff0000}, // v1
    { 0.5f,  0.5f,  0.5f, 0xffff0000}, // v2
    {-0.5f,  0.5f,  0.5f, 0xffff0000}, // v3
    // Back face
    {-0.5f, -0.5f, -0.5f, 0xffffff00}, // v4
    { 0.5f, -0.5f, -0.5f, 0xffffff00}, // v5
    { 0.5f,  0.5f, -0.5f, 0xffffff00}, // v6
    {-0.5f,  0.5f, -0.5f, 0xffffff00}, // v7
    // Top face
    { 0.5f,  0.5f,  0.5f, 0xff00ff00}, // v2
    {-0.5f,  0.5f,  0.5f, 0xff00ff00}, // v3
    {-0.5f,  0.5f, -0.5f, 0xff00ff00}, // v7
    { 0.5f,  0.5f, -0.5f, 0xff00ff00}, // v6
    // Bottom face
    {-0.5f, -0.5f,  0.5f, 0xffff7f7f}, // v0
    { 0.5f, -0.5f,  0.5f, 0xffff7f7f}, // v1
    { 0.5f, -0.5f, -0.5f, 0xffff7f7f}, // v5
    {-0.5f, -0.5f, -0.5f, 0xffff7f7f}, // v4
    // Right face
    { 0.5f, -0.5f,  0.5f, 0xffff00ff}, // v1
    { 0.5f,  0.5f,  0.5f, 0xffff00ff}, // v2
    { 0.5f,  0.5f, -0.5f, 0xffff00ff}, // v6
    { 0.5f, -0.5f, -0.5f, 0xffff00ff}, // v5
    // Left face
    {-0.5f, -0.5f,  0.5f, 0xff0000ff}, // v0
    {-0.5f,  0.5f,  0.5f, 0xff0000ff}, // v3
    {-0.5f,  0.5f, -0.5f, 0xff0000ff}, // v7
    {-0.5f, -0.5f, -0.5f, 0xff0000ff}  // v4
};

WORD g_Indices[] =
{
     0,  1,  2,    0,  2,  3,  // Front face
     4,  5,  6,    4,  6,  7,  // Back face
     8,  9, 10,    8, 10, 11,  // Top face
    12, 13, 14,   12, 14, 15,  // Bottom face
    16, 17, 18,   16, 18, 19,  // Right face
    20, 21, 22,   20, 22, 23   // Left face
};

VOID SetupMatrices();

#define D3DFVF_CUSTOMVERTEX (D3DFVF_XYZ | D3DFVF_DIFFUSE)

VOID InitD3D(HWND hWnd)
{
    g_pD3D = Direct3DCreate9(D3D_SDK_VERSION);

    D3DPRESENT_PARAMETERS d3dpp;
    ZeroMemory(&d3dpp, sizeof(d3dpp));
    d3dpp.Windowed = TRUE;
    d3dpp.SwapEffect = D3DSWAPEFFECT_DISCARD;
    d3dpp.BackBufferFormat = D3DFMT_UNKNOWN;

    g_pD3D->CreateDevice(
        D3DADAPTER_DEFAULT, D3DDEVTYPE_HAL, hWnd,
        D3DCREATE_SOFTWARE_VERTEXPROCESSING,
        &d3dpp, &g_pd3dDevice);

}

HRESULT InitGeometry()
{
    if (FAILED(g_pd3dDevice->CreateVertexBuffer(24 * sizeof(CUSTOMVERTEX), 0, D3DFVF_CUSTOMVERTEX, D3DPOOL_DEFAULT, &g_pVB, NULL)))
    {
        return E_FAIL;
    }

    VOID* pVertices;
    if (FAILED(g_pVB->Lock(0, sizeof(g_Vertices), (void**)&pVertices, 0)))
        return E_FAIL;

    memcpy(pVertices, g_Vertices, sizeof(g_Vertices));
    g_pVB->Unlock();

    if (FAILED(g_pd3dDevice->CreateIndexBuffer(36 * sizeof(WORD),  0, D3DFMT_INDEX16, D3DPOOL_DEFAULT, &g_pIB, NULL)))
    {
        return E_FAIL;
    }

    VOID* pIndices;
    if (FAILED(g_pIB->Lock(0, sizeof(g_Indices), (void**)&pIndices, 0)))
        return E_FAIL;

    memcpy(pIndices, g_Indices, sizeof(g_Indices));
    g_pIB->Unlock();

    return S_OK;
}

VOID SetupMatrices()
{
    D3DXMATRIXA16 matView;
    D3DXVECTOR3 vEyePt(0.0f, 3.0f, -5.0f);
    D3DXVECTOR3 vLookatPt(0.0f, 0.0f, 0.0f);
    D3DXVECTOR3 vUpVec(0.0f, 1.0f, 0.0f);
    D3DXMatrixLookAtLH(&matView, &vEyePt, &vLookatPt, &vUpVec);
    g_pd3dDevice->SetTransform(D3DTS_VIEW, &matView);

    D3DXMATRIXA16 matProj;
    float aspect = 640.0 / 480.0;
    D3DXMatrixPerspectiveFovLH(&matProj, D3DX_PI / 4, aspect, 1.0f, 100.0f);
    g_pd3dDevice->SetTransform(D3DTS_PROJECTION, &matProj);

    static float fAngle = 0.0f;
    fAngle += 0.05f;
    D3DXMATRIXA16 matWorld;
    D3DXMatrixRotationYawPitchRoll(&matWorld, fAngle, 0, 0);
    g_pd3dDevice->SetTransform(D3DTS_WORLD, &matWorld);

    g_pd3dDevice->SetRenderState(D3DRS_LIGHTING, FALSE);
    g_pd3dDevice->SetRenderState(D3DRS_CULLMODE, D3DCULL_NONE);
}

VOID Render()
{
    if (NULL == g_pd3dDevice)
        return;

    g_pd3dDevice->Clear(0, NULL, D3DCLEAR_TARGET, D3DCOLOR_XRGB(255, 255, 255), 1.0f, 0);

    if (SUCCEEDED(g_pd3dDevice->BeginScene()))
    {
        SetupMatrices();
        g_pd3dDevice->SetIndices(g_pIB);
        g_pd3dDevice->SetStreamSource(0, g_pVB, 0, sizeof(CUSTOMVERTEX));
        g_pd3dDevice->SetFVF(D3DFVF_CUSTOMVERTEX);
        g_pd3dDevice->DrawIndexedPrimitive(D3DPT_TRIANGLELIST, 0, 0, 24, 0, 12);
        g_pd3dDevice->EndScene();
    }

    g_pd3dDevice->Present(NULL, NULL, NULL, NULL);
}

VOID Cleanup()
{
    if (g_pVB != NULL)
    g_pVB->Release();

    if (g_pd3dDevice != NULL)
        g_pd3dDevice->Release();

    if (g_pD3D != NULL)
        g_pD3D->Release();

}

LRESULT WINAPI MsgProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
        case WM_DESTROY:
            Cleanup();
            PostQuitMessage(0);
            return 0;

        case WM_PAINT:
            Render();
            ValidateRect(hWnd, NULL);
            return 0;
    }

    return DefWindowProc(hWnd, msg, wParam, lParam);
}

INT WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, INT)
{
    WNDCLASSEX wc = { 
        sizeof(WNDCLASSEX), CS_CLASSDC, MsgProc, 0L, 0L,
        GetModuleHandle(NULL), NULL, NULL, NULL, NULL,
        "helloWorld", NULL 
    };
    RegisterClassEx(&wc);

    HWND hWnd = CreateWindow(
        "helloWorld", 
        "Hello, World!",
         WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
         GetDesktopWindow(), NULL, wc.hInstance, NULL);

    if (SUCCEEDED(hWnd))
    {
        ShowWindow(hWnd, SW_SHOWDEFAULT);
        UpdateWindow(hWnd);

        InitD3D(hWnd);
        InitGeometry();

        MSG msg;
        ZeroMemory(&msg, sizeof(msg));
        while (msg.message != WM_QUIT)
        {
            if (PeekMessage(&msg, NULL, 0U, 0U, PM_REMOVE))
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
            else
                Render();
        }
    }

    UnregisterClass("helloWorld", wc.hInstance);

    return 0;
}
