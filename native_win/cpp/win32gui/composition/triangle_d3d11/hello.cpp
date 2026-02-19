// hello_dcomp.cpp - D3D11 Triangle via DirectComposition (pure Win32 COM, no WinRT)
//
// Build (Visual Studio Developer Command Prompt):
//   cl /EHsc /std:c++17 hello_dcomp.cpp /link d3d11.lib dxgi.lib d3dcompiler.lib dcomp.lib user32.lib
//
// DirectComposition is available on Windows 8 and later.
// No WinRT runtime required (no RoInitialize, no DispatcherQueue, etc.)
//
// Debug output goes to OutputDebugString - use DebugView (SysInternals) to monitor.

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <d3dcompiler.h>
#include <dcomp.h>
#include <cstdio>
#include <cstdarg>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "dcomp.lib")
#pragma comment(lib, "user32.lib")

// ============================================================
// Debug output helper - sends formatted text to DebugView
// ============================================================
static void dbg(const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
}

// ============================================================
// Constants
// ============================================================
static const int WIDTH  = 640;
static const int HEIGHT = 480;
static const wchar_t* CLASS_NAME  = L"DCompTriangleClass";
static const wchar_t* WINDOW_NAME = L"D3D11 Triangle (DirectComposition)";

// ============================================================
// D3D11 globals
// ============================================================
static ID3D11Device*           g_device       = nullptr;
static ID3D11DeviceContext*    g_context      = nullptr;
static IDXGISwapChain1*        g_swapChain    = nullptr;
static ID3D11RenderTargetView* g_rtv          = nullptr;
static ID3D11VertexShader*     g_vertexShader = nullptr;
static ID3D11PixelShader*      g_pixelShader  = nullptr;
static ID3D11InputLayout*      g_inputLayout  = nullptr;
static ID3D11Buffer*           g_vertexBuffer = nullptr;

// ============================================================
// DirectComposition globals
// ============================================================
static IDCompositionDevice*    g_dcompDevice  = nullptr;
static IDCompositionTarget*    g_dcompTarget  = nullptr;
static IDCompositionVisual*    g_dcompVisual  = nullptr;

// ============================================================
// Embedded HLSL shaders
// ============================================================
static const char* g_shaderSource = R"(
struct VS_INPUT {
    float3 Pos   : POSITION;
    float4 Color : COLOR;
};

struct PS_INPUT {
    float4 Pos   : SV_POSITION;
    float4 Color : COLOR;
};

PS_INPUT VS(VS_INPUT input) {
    PS_INPUT output;
    output.Pos   = float4(input.Pos, 1.0f);
    output.Color = input.Color;
    return output;
}

float4 PS(PS_INPUT input) : SV_Target {
    return input.Color;
}
)";

// ============================================================
// Vertex data
// ============================================================
struct Vertex {
    float x, y, z;
    float r, g, b, a;
};

static Vertex g_vertices[] = {
    {  0.0f,  0.5f, 0.0f,   1.0f, 0.0f, 0.0f, 1.0f },  // Top    (Red)
    {  0.5f, -0.5f, 0.0f,   0.0f, 1.0f, 0.0f, 1.0f },  // Right  (Green)
    { -0.5f, -0.5f, 0.0f,   0.0f, 0.0f, 1.0f, 1.0f },  // Left   (Blue)
};

// ============================================================
// Helper: safe release
// ============================================================
template <typename T>
void SafeRelease(T** pp) {
    if (*pp) {
        (*pp)->Release();
        *pp = nullptr;
    }
}

// ============================================================
// Window procedure
// ============================================================
LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE)
            PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

// ============================================================
// Create Win32 window
// ============================================================
HWND CreateAppWindow(HINSTANCE hInstance) {
    dbg("[CreateAppWindow] begin\n");

    WNDCLASSEXW wc = {};
    wc.cbSize        = sizeof(wc);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = WndProc;
    wc.hInstance      = hInstance;
    wc.hCursor        = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName  = CLASS_NAME;

    if (!RegisterClassExW(&wc)) {
        dbg("[CreateAppWindow] RegisterClassEx failed: %lu\n", GetLastError());
        return nullptr;
    }
    dbg("[CreateAppWindow] RegisterClassEx ok\n");

    RECT rc = { 0, 0, WIDTH, HEIGHT };
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hwnd = CreateWindowExW(
        0, CLASS_NAME, WINDOW_NAME,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        nullptr, nullptr, hInstance, nullptr);

    if (!hwnd) {
        dbg("[CreateAppWindow] CreateWindowEx failed: %lu\n", GetLastError());
        return nullptr;
    }

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    dbg("[CreateAppWindow] HWND=%p\n", hwnd);
    return hwnd;
}

// ============================================================
// Initialize D3D11 - Device + SwapChain (ForComposition)
// ============================================================
bool InitD3D11() {
    HRESULT hr;
    dbg("[InitD3D11] begin\n");

    // Step 1: Create D3D11 device
    D3D_FEATURE_LEVEL featureLevel;
    D3D_FEATURE_LEVEL levels[] = { D3D_FEATURE_LEVEL_11_0 };
    UINT flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
#ifdef _DEBUG
    flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

    hr = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        flags, levels, 1,
        D3D11_SDK_VERSION,
        &g_device, &featureLevel, &g_context);
    if (FAILED(hr)) {
        dbg("[InitD3D11] D3D11CreateDevice failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitD3D11] Device=%p Context=%p\n", g_device, g_context);

    // Step 2: Get DXGI Device -> Adapter -> Factory2
    IDXGIDevice* dxgiDevice = nullptr;
    hr = g_device->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDevice);
    if (FAILED(hr)) {
        dbg("[InitD3D11] QI IDXGIDevice failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitD3D11] IDXGIDevice=%p\n", dxgiDevice);

    IDXGIAdapter* adapter = nullptr;
    hr = dxgiDevice->GetAdapter(&adapter);
    if (FAILED(hr)) {
        dbg("[InitD3D11] GetAdapter failed: hr=0x%08X\n", hr);
        dxgiDevice->Release();
        return false;
    }

    IDXGIFactory2* factory = nullptr;
    hr = adapter->GetParent(__uuidof(IDXGIFactory2), (void**)&factory);
    adapter->Release();
    if (FAILED(hr)) {
        dbg("[InitD3D11] GetParent IDXGIFactory2 failed: hr=0x%08X\n", hr);
        dxgiDevice->Release();
        return false;
    }
    dbg("[InitD3D11] IDXGIFactory2=%p\n", factory);

    // Step 3: Create SwapChain FOR COMPOSITION (not bound to any HWND)
    DXGI_SWAP_CHAIN_DESC1 scd = {};
    scd.Width       = WIDTH;
    scd.Height      = HEIGHT;
    scd.Format      = DXGI_FORMAT_B8G8R8A8_UNORM;
    scd.SampleDesc  = { 1, 0 };
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scd.BufferCount = 2;
    scd.SwapEffect  = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    scd.AlphaMode   = DXGI_ALPHA_MODE_PREMULTIPLIED;

    hr = factory->CreateSwapChainForComposition(g_device, &scd, nullptr, &g_swapChain);
    factory->Release();
    if (FAILED(hr)) {
        dbg("[InitD3D11] CreateSwapChainForComposition failed: hr=0x%08X\n", hr);
        dxgiDevice->Release();
        return false;
    }
    dbg("[InitD3D11] SwapChain=%p (ForComposition)\n", g_swapChain);

    // Step 4: Create render target view from back buffer
    ID3D11Texture2D* backBuffer = nullptr;
    hr = g_swapChain->GetBuffer(0, __uuidof(ID3D11Texture2D), (void**)&backBuffer);
    if (FAILED(hr)) {
        dbg("[InitD3D11] GetBuffer failed: hr=0x%08X\n", hr);
        dxgiDevice->Release();
        return false;
    }

    hr = g_device->CreateRenderTargetView(backBuffer, nullptr, &g_rtv);
    backBuffer->Release();
    if (FAILED(hr)) {
        dbg("[InitD3D11] CreateRenderTargetView failed: hr=0x%08X\n", hr);
        dxgiDevice->Release();
        return false;
    }
    dbg("[InitD3D11] RTV=%p\n", g_rtv);

    // Step 5: Compile and create shaders (embedded HLSL)
    ID3DBlob* vsBlob = nullptr;
    ID3DBlob* psBlob = nullptr;
    ID3DBlob* errBlob = nullptr;

    hr = D3DCompile(g_shaderSource, strlen(g_shaderSource), "embedded",
                    nullptr, nullptr, "VS", "vs_4_0", 0, 0, &vsBlob, &errBlob);
    if (FAILED(hr)) {
        if (errBlob) dbg("[InitD3D11] VS compile error: %s\n", (char*)errBlob->GetBufferPointer());
        SafeRelease(&errBlob);
        dxgiDevice->Release();
        return false;
    }
    dbg("[InitD3D11] VS compiled ok\n");

    hr = D3DCompile(g_shaderSource, strlen(g_shaderSource), "embedded",
                    nullptr, nullptr, "PS", "ps_4_0", 0, 0, &psBlob, &errBlob);
    if (FAILED(hr)) {
        if (errBlob) dbg("[InitD3D11] PS compile error: %s\n", (char*)errBlob->GetBufferPointer());
        SafeRelease(&errBlob);
        SafeRelease(&vsBlob);
        dxgiDevice->Release();
        return false;
    }
    dbg("[InitD3D11] PS compiled ok\n");

    g_device->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, &g_vertexShader);
    g_device->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, &g_pixelShader);
    dbg("[InitD3D11] VS=%p PS=%p\n", g_vertexShader, g_pixelShader);

    // Step 6: Create input layout
    D3D11_INPUT_ELEMENT_DESC layout[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT,  0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };
    hr = g_device->CreateInputLayout(layout, 2,
        vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), &g_inputLayout);
    SafeRelease(&vsBlob);
    SafeRelease(&psBlob);
    if (FAILED(hr)) {
        dbg("[InitD3D11] CreateInputLayout failed: hr=0x%08X\n", hr);
        dxgiDevice->Release();
        return false;
    }
    dbg("[InitD3D11] InputLayout=%p\n", g_inputLayout);

    // Step 7: Create vertex buffer
    D3D11_BUFFER_DESC bd = {};
    bd.ByteWidth = sizeof(g_vertices);
    bd.Usage     = D3D11_USAGE_DEFAULT;
    bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;

    D3D11_SUBRESOURCE_DATA initData = {};
    initData.pSysMem = g_vertices;

    hr = g_device->CreateBuffer(&bd, &initData, &g_vertexBuffer);
    dxgiDevice->Release();
    if (FAILED(hr)) {
        dbg("[InitD3D11] CreateBuffer failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitD3D11] VertexBuffer=%p\n", g_vertexBuffer);

    dbg("[InitD3D11] all resources created successfully\n");
    return true;
}

// ============================================================
// Initialize DirectComposition - pure COM, no WinRT required
// ============================================================
bool InitDirectComposition(HWND hwnd) {
    HRESULT hr;
    dbg("[InitDComp] begin\n");

    // Step 1: Create DComp device from DXGI device
    // DCompositionCreateDevice() takes an IDXGIDevice which we obtain
    // by QueryInterface from the D3D11 device.
    IDXGIDevice* dxgiDevice = nullptr;
    hr = g_device->QueryInterface(__uuidof(IDXGIDevice), (void**)&dxgiDevice);
    if (FAILED(hr)) {
        dbg("[InitDComp] QI IDXGIDevice failed: hr=0x%08X\n", hr);
        return false;
    }

    hr = DCompositionCreateDevice(dxgiDevice, __uuidof(IDCompositionDevice), (void**)&g_dcompDevice);
    dxgiDevice->Release();
    if (FAILED(hr)) {
        dbg("[InitDComp] DCompositionCreateDevice failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] DCompDevice=%p\n", g_dcompDevice);

    // Step 2: Create a composition target bound to the HWND
    // This tells DWM to overlay the composition visual tree onto this window.
    hr = g_dcompDevice->CreateTargetForHwnd(hwnd, TRUE, &g_dcompTarget);
    if (FAILED(hr)) {
        dbg("[InitDComp] CreateTargetForHwnd failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] DCompTarget=%p\n", g_dcompTarget);

    // Step 3: Create a visual
    hr = g_dcompDevice->CreateVisual(&g_dcompVisual);
    if (FAILED(hr)) {
        dbg("[InitDComp] CreateVisual failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] DCompVisual=%p\n", g_dcompVisual);

    // Step 4: Set the swap chain as the visual's content
    // This is the key advantage of DirectComposition over WinRT Composition:
    // the swap chain can be passed directly via SetContent().
    // No need for the Surface -> Brush -> SpriteVisual conversion chain.
    hr = g_dcompVisual->SetContent(g_swapChain);
    if (FAILED(hr)) {
        dbg("[InitDComp] SetContent failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] SetContent(SwapChain) ok\n");

    // Step 5: Build the tree - set the visual as the target's root
    hr = g_dcompTarget->SetRoot(g_dcompVisual);
    if (FAILED(hr)) {
        dbg("[InitDComp] SetRoot failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] SetRoot ok\n");

    // Step 6: Commit - push pending changes to DWM
    // Unlike WinRT Composition (which auto-commits), DirectComposition
    // requires an explicit Commit() call. Nothing appears on screen
    // until this is called.
    hr = g_dcompDevice->Commit();
    if (FAILED(hr)) {
        dbg("[InitDComp] Commit failed: hr=0x%08X\n", hr);
        return false;
    }
    dbg("[InitDComp] Commit ok - composition tree is now active\n");

    return true;
}

// ============================================================
// Render - draw the triangle with D3D11
// ============================================================
static bool g_firstFrame = true;

void Render() {
    // Clear to white
    float clearColor[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    g_context->ClearRenderTargetView(g_rtv, clearColor);

    // Set render target and viewport
    g_context->OMSetRenderTargets(1, &g_rtv, nullptr);

    D3D11_VIEWPORT vp = { 0.0f, 0.0f, (float)WIDTH, (float)HEIGHT, 0.0f, 1.0f };
    g_context->RSSetViewports(1, &vp);

    // Set input assembler state
    g_context->IASetInputLayout(g_inputLayout);
    UINT stride = sizeof(Vertex);
    UINT offset = 0;
    g_context->IASetVertexBuffers(0, 1, &g_vertexBuffer, &stride, &offset);
    g_context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    // Set shaders
    g_context->VSSetShader(g_vertexShader, nullptr, 0);
    g_context->PSSetShader(g_pixelShader,  nullptr, 0);

    // Draw the triangle
    g_context->Draw(3, 0);

    // Present - the swap chain content is composited onto the window via DComp
    HRESULT hr = g_swapChain->Present(1, 0);

    if (g_firstFrame) {
        dbg("[Render] first frame Present hr=0x%08X\n", hr);
        g_firstFrame = false;
    }
}

// ============================================================
// Cleanup - release all resources
// ============================================================
void Cleanup() {
    dbg("[Cleanup] begin\n");

    // DirectComposition resources
    SafeRelease(&g_dcompVisual);
    SafeRelease(&g_dcompTarget);
    SafeRelease(&g_dcompDevice);

    // D3D11 resources
    SafeRelease(&g_vertexBuffer);
    SafeRelease(&g_inputLayout);
    SafeRelease(&g_pixelShader);
    SafeRelease(&g_vertexShader);
    SafeRelease(&g_rtv);
    SafeRelease(&g_swapChain);
    SafeRelease(&g_context);
    SafeRelease(&g_device);

    dbg("[Cleanup] all resources released\n");
}

// ============================================================
// Entry point
// ============================================================
int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int) {
    dbg("========================================\n");
    dbg("D3D11 Triangle via DirectComposition\n");
    dbg("No WinRT - dcomp.dll only\n");
    dbg("========================================\n");

    // 1. Create the Win32 window
    HWND hwnd = CreateAppWindow(hInstance);
    if (!hwnd) return 1;

    // 2. Initialize D3D11 (SwapChainForComposition - not bound to HWND)
    if (!InitD3D11()) {
        dbg("[Main] InitD3D11 failed\n");
        return 1;
    }

    // 3. Initialize DirectComposition
    //    - DCompositionCreateDevice()
    //    - CreateTargetForHwnd()  - bind to HWND
    //    - CreateVisual() + SetContent(swapChain)  - pass swap chain directly
    //    - SetRoot() + Commit()  - push to DWM
    if (!InitDirectComposition(hwnd)) {
        dbg("[Main] InitDirectComposition failed\n");
        Cleanup();
        return 1;
    }

    // 4. First frame
    Render();
    dbg("[Main] entering message loop\n");

    // 5. Message loop
    MSG msg = {};
    while (msg.message != WM_QUIT) {
        if (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        } else {
            Render();
        }
    }

    // 6. Cleanup
    Cleanup();
    dbg("[Main] exit\n");

    return 0;
}
