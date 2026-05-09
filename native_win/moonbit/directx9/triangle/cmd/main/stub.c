#include <windows.h>
#include <d3d9.h>
#include <string.h>

typedef struct _VERTEX {
    float x;
    float y;
    float z;
    float rhw;
    DWORD color;
} VERTEX;

#define D3DFVF_VERTEX (D3DFVF_XYZRHW | D3DFVF_DIFFUSE)

static LPDIRECT3D9 g_pD3D = NULL;
static LPDIRECT3DDEVICE9 g_pd3dDevice = NULL;
static LPDIRECT3DVERTEXBUFFER9 g_pVB = NULL;

static LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
static HRESULT InitD3D(HWND hWnd);
static HRESULT InitVB(void);
static void Cleanup(void);
static void Render(void);

void run_directx9(void) {
    WNDCLASSEXA wcex;
    HWND hwnd;
    MSG msg;
    BOOL bQuit = FALSE;
    HINSTANCE hInstance = GetModuleHandleA(NULL);

    wcex.cbSize = sizeof(WNDCLASSEXA);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = WindowProc;
    wcex.cbClsExtra = 0;
    wcex.cbWndExtra = 0;
    wcex.hInstance = hInstance;
    wcex.hIcon = LoadIconA(NULL, IDI_APPLICATION);
    wcex.hCursor = LoadCursorA(NULL, IDC_ARROW);
    wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wcex.lpszMenuName = NULL;
    wcex.lpszClassName = "helloWindow";
    wcex.hIconSm = LoadIconA(NULL, IDI_APPLICATION);

    if (!RegisterClassExA(&wcex)) {
        return;
    }

    hwnd = CreateWindowExA(
        0,
        "helloWindow",
        "Hello, World!",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        640,
        480,
        NULL,
        NULL,
        hInstance,
        NULL
    );

    if (hwnd == NULL) {
        return;
    }

    if (FAILED(InitD3D(hwnd))) {
        DestroyWindow(hwnd);
        return;
    }

    if (FAILED(InitVB())) {
        Cleanup();
        DestroyWindow(hwnd);
        return;
    }

    ShowWindow(hwnd, SW_SHOWDEFAULT);
    UpdateWindow(hwnd);

    while (!bQuit) {
        if (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                bQuit = TRUE;
            } else {
                TranslateMessage(&msg);
                DispatchMessageA(&msg);
            }
        } else {
            Render();
        }
    }

    Cleanup();
    DestroyWindow(hwnd);
}

static LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcA(hWnd, uMsg, wParam, lParam);
    }
}

static HRESULT InitD3D(HWND hWnd) {
    D3DPRESENT_PARAMETERS d3dpp;

    g_pD3D = Direct3DCreate9(D3D_SDK_VERSION);
    if (g_pD3D == NULL) {
        return E_FAIL;
    }

    ZeroMemory(&d3dpp, sizeof(d3dpp));
    d3dpp.Windowed = TRUE;
    d3dpp.SwapEffect = D3DSWAPEFFECT_DISCARD;
    d3dpp.BackBufferFormat = D3DFMT_UNKNOWN;

    if (FAILED(g_pD3D->lpVtbl->CreateDevice(
            g_pD3D,
            D3DADAPTER_DEFAULT,
            D3DDEVTYPE_HAL,
            hWnd,
            D3DCREATE_SOFTWARE_VERTEXPROCESSING,
            &d3dpp,
            &g_pd3dDevice))) {
        return E_FAIL;
    }

    return S_OK;
}

static HRESULT InitVB(void) {
    VERTEX vertices[] = {
        {300.0f, 100.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(255, 0, 0)},
        {500.0f, 400.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 255, 0)},
        {100.0f, 400.0f, 0.0f, 1.0f, D3DCOLOR_XRGB(0, 0, 255)},
    };
    void *pVertices;

    if (FAILED(g_pd3dDevice->lpVtbl->CreateVertexBuffer(
            g_pd3dDevice,
            (UINT)(3 * sizeof(VERTEX)),
            0,
            D3DFVF_VERTEX,
            D3DPOOL_DEFAULT,
            &g_pVB,
            NULL))) {
        return E_FAIL;
    }

    if (FAILED(g_pVB->lpVtbl->Lock(g_pVB, 0, sizeof(vertices), (void **)&pVertices, 0))) {
        return E_FAIL;
    }

    memcpy(pVertices, vertices, sizeof(vertices));
    g_pVB->lpVtbl->Unlock(g_pVB);

    return S_OK;
}

static void Cleanup(void) {
    if (g_pVB != NULL) {
        g_pVB->lpVtbl->Release(g_pVB);
        g_pVB = NULL;
    }

    if (g_pd3dDevice != NULL) {
        g_pd3dDevice->lpVtbl->Release(g_pd3dDevice);
        g_pd3dDevice = NULL;
    }

    if (g_pD3D != NULL) {
        g_pD3D->lpVtbl->Release(g_pD3D);
        g_pD3D = NULL;
    }
}

static void Render(void) {
    if (g_pd3dDevice == NULL) {
        return;
    }

    g_pd3dDevice->lpVtbl->Clear(
        g_pd3dDevice,
        0,
        NULL,
        D3DCLEAR_TARGET,
        D3DCOLOR_XRGB(255, 255, 255),
        1.0f,
        0
    );

    if (SUCCEEDED(g_pd3dDevice->lpVtbl->BeginScene(g_pd3dDevice))) {
        g_pd3dDevice->lpVtbl->SetStreamSource(g_pd3dDevice, 0, g_pVB, 0, sizeof(VERTEX));
        g_pd3dDevice->lpVtbl->SetFVF(g_pd3dDevice, D3DFVF_VERTEX);
        g_pd3dDevice->lpVtbl->DrawPrimitive(g_pd3dDevice, D3DPT_TRIANGLELIST, 0, 1);
        g_pd3dDevice->lpVtbl->EndScene(g_pd3dDevice);
    }

    g_pd3dDevice->lpVtbl->Present(g_pd3dDevice, NULL, NULL, NULL, NULL);
}
