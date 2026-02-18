// hello.cpp
// Win32 window + D3D11 render triangle into a DXGI swapchain created by
// CreateSwapChainForComposition, then show it via Windows.UI.Composition
// Desktop interop (DesktopWindowTarget) on classic desktop apps.
//
// Logging: DebugView only (OutputDebugStringW). No console, no MessageBox.
//
// Build example (adjust Windows Kits path if needed):
//   cl /std:c++20 /EHsc /DUNICODE /D_UNICODE hello.cpp ^
//     /I "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\cppwinrt" ^
//     user32.lib gdi32.lib ole32.lib windowsapp.lib ^
//     d3d11.lib dxgi.lib d3dcompiler.lib CoreMessaging.lib

#include <windows.h>
#include <unknwn.h>
#include <stdint.h>
#include <stdarg.h>

#include <d3d11.h>
#include <dxgi1_2.h>
#include <d3dcompiler.h>
#include <wrl/client.h>

#include <DispatcherQueue.h>
#pragma comment(lib, "CoreMessaging.lib")

#include <winrt/base.h>
#include <winrt/Windows.UI.Composition.h>
#include <winrt/Windows.UI.Composition.Desktop.h>

// Interop interfaces (Desktop target + surface for swapchain)
#include <windows.ui.composition.interop.h>
#include <windows.ui.composition.desktop.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "windowsapp.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3dcompiler.lib")

using Microsoft::WRL::ComPtr;

// ------------------------------------------------------------
// Debug logging: DebugView only
// ------------------------------------------------------------
static void dbgprintf(const wchar_t* fmt, ...)
{
    wchar_t buf[2048];
    va_list ap;
    va_start(ap, fmt);
    _vsnwprintf_s(buf, _countof(buf), _TRUNCATE, fmt, ap);
    va_end(ap);
    OutputDebugStringW(buf);
}

static void dbg_step(const wchar_t* fn, const wchar_t* msg)
{
    dbgprintf(L"[STEP] %s : %s\n", fn, msg);
}

static void dbg_hr(const wchar_t* fn, const wchar_t* api, HRESULT hr)
{
    dbgprintf(L"[ERR ] %s : %s failed hr=0x%08X\n", fn, api, (uint32_t)hr);
}

static void LogWin32Error(const wchar_t* fn, const wchar_t* api, DWORD gle)
{
    wchar_t msg[1024]{};
    FormatMessageW(
        FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
        nullptr, gle,
        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
        msg, (DWORD)_countof(msg),
        nullptr
    );
    dbgprintf(L"[WIN ] %s : %s failed GLE=%lu (0x%08X) %s\n",
              fn, api, gle, (uint32_t)gle, msg);
}

// ------------------------------------------------------------
// Globals
// ------------------------------------------------------------
static HWND g_hwnd = nullptr;
static UINT g_width = 640;
static UINT g_height = 480;

// COM init flag
static bool g_comInitialized = false;

// DispatcherQueue controller (keep alive)
static ABI::Windows::System::IDispatcherQueueController* g_dqController = nullptr;

// D3D11 objects
static ComPtr<ID3D11Device>            g_d3dDevice;
static ComPtr<ID3D11DeviceContext>     g_d3dCtx;
static ComPtr<IDXGISwapChain1>         g_swapChain;
static ComPtr<ID3D11RenderTargetView>  g_rtv;
static ComPtr<ID3D11VertexShader>      g_vs;
static ComPtr<ID3D11PixelShader>       g_ps;
static ComPtr<ID3D11InputLayout>       g_inputLayout;
static ComPtr<ID3D11Buffer>            g_vb;

// Composition objects
static winrt::Windows::UI::Composition::Compositor g_compositor{ nullptr };
static winrt::Windows::UI::Composition::Desktop::DesktopWindowTarget g_target{ nullptr };
static winrt::Windows::UI::Composition::ContainerVisual g_root{ nullptr };
static winrt::Windows::UI::Composition::SpriteVisual g_sprite{ nullptr };

// ------------------------------------------------------------
// Win32 window proc
// ------------------------------------------------------------
static LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;

    case WM_PAINT:
    {
        PAINTSTRUCT ps{};
        BeginPaint(hWnd, &ps);
        EndPaint(hWnd, &ps);
        return 0;
    }

    default:
        return DefWindowProcW(hWnd, msg, wParam, lParam);
    }
}

// ------------------------------------------------------------
// Create window
// ------------------------------------------------------------
static HRESULT CreateAppWindow(HINSTANCE hInst)
{
    const wchar_t* FN = L"CreateAppWindow";
    dbg_step(FN, L"begin");

    const wchar_t* kClassName = L"Win32CompTriangle";

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.hInstance = hInst;
    wc.lpszClassName = kClassName;
    wc.lpfnWndProc = WndProc;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);

    if (!RegisterClassExW(&wc))
    {
        DWORD gle = GetLastError();
        if (gle != ERROR_CLASS_ALREADY_EXISTS)
        {
            LogWin32Error(FN, L"RegisterClassExW", gle);
            return HRESULT_FROM_WIN32(gle);
        }
        dbg_step(FN, L"RegisterClassExW: class already exists (ok)");
    }
    else
    {
        dbg_step(FN, L"RegisterClassExW ok");
    }

    DWORD style = WS_OVERLAPPEDWINDOW;

    RECT rc{ 0, 0, (LONG)g_width, (LONG)g_height };
    AdjustWindowRect(&rc, style, FALSE);

    // Sentinel to detect "LastError not updated"
    SetLastError(0xDEADBEEF);

    g_hwnd = CreateWindowExW(
        0,
        kClassName,
        L"D3D11 Triangle via Windows.UI.Composition (Win32)",
        style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        nullptr, nullptr, hInst, nullptr
    );

    if (!g_hwnd)
    {
        DWORD gle = GetLastError();

        if (gle == 0 || gle == 0xDEADBEEF)
        {
            dbgprintf(L"[WIN ] %s : CreateWindowExW returned NULL but GetLastError=%lu (0x%08X)\n",
                      FN, gle, (uint32_t)gle);
            dbgprintf(L"[WIN ] %s : Likely indicates memory corruption or invalid state before calling user32.\n", FN);
            // Return a deterministic error
            return E_INVALIDARG;
        }

        LogWin32Error(FN, L"CreateWindowExW", gle);
        return HRESULT_FROM_WIN32(gle);
    }

    dbgprintf(L"[INFO] %s : hwnd=0x%p\n", FN, g_hwnd);

    ShowWindow(g_hwnd, SW_SHOW);
    UpdateWindow(g_hwnd);

    dbg_step(FN, L"ok");
    return S_OK;
}

// ------------------------------------------------------------
// DispatcherQueue (required for some Composition operations)
// ------------------------------------------------------------
static HRESULT InitDispatcherQueueForCurrentThread()
{
    const wchar_t* FN = L"InitDispatcherQueueForCurrentThread";
    dbg_step(FN, L"begin");

    if (g_dqController)
    {
        dbg_step(FN, L"already initialized");
        return S_OK;
    }

    DispatcherQueueOptions opt{};
    opt.dwSize = sizeof(opt);
    opt.threadType = DQTYPE_THREAD_CURRENT;
    opt.apartmentType = DQTAT_COM_STA;

    HRESULT hr = CreateDispatcherQueueController(
        opt,
        reinterpret_cast<ABI::Windows::System::IDispatcherQueueController**>(&g_dqController)
    );
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateDispatcherQueueController", hr);
        return hr;
    }

    dbg_step(FN, L"ok (controller created)");
    return S_OK;
}

// ------------------------------------------------------------
// D3D11 shader sources (embedded)
// ------------------------------------------------------------
struct Vertex { float x, y, z; float r, g, b, a; };

static const char* kVS_HLSL = R"(
struct VSInput { float3 pos:POSITION; float4 col:COLOR; };
struct VSOutput{ float4 pos:SV_POSITION; float4 col:COLOR; };
VSOutput main(VSInput i){ VSOutput o; o.pos=float4(i.pos,1); o.col=i.col; return o; }
)";

static const char* kPS_HLSL = R"(
struct PSInput { float4 pos:SV_POSITION; float4 col:COLOR; };
float4 main(PSInput i):SV_TARGET{ return i.col; }
)";

static HRESULT Compile(const char* src, const char* entry, const char* target, ComPtr<ID3DBlob>& outBlob)
{
    const wchar_t* FN = L"Compile";
    dbg_step(FN, L"begin");

    UINT flags = D3DCOMPILE_ENABLE_STRICTNESS;
#if defined(_DEBUG)
    flags |= D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
#endif

    ComPtr<ID3DBlob> err;
    HRESULT hr = D3DCompile(src, strlen(src), nullptr, nullptr, nullptr, entry, target, flags, 0, &outBlob, &err);
    if (FAILED(hr))
    {
        if (err)
        {
            OutputDebugStringA((const char*)err->GetBufferPointer());
            OutputDebugStringA("\n");
        }
        dbg_hr(FN, L"D3DCompile", hr);
        return hr;
    }

    dbg_step(FN, L"ok");
    return S_OK;
}

// ------------------------------------------------------------
// D3D11 + Swapchain for Composition
// ------------------------------------------------------------
static HRESULT CreateRenderTarget()
{
    const wchar_t* FN = L"CreateRenderTarget";
    dbg_step(FN, L"begin");

    g_rtv.Reset();

    ComPtr<ID3D11Texture2D> backBuffer;
    HRESULT hr = g_swapChain->GetBuffer(0, IID_PPV_ARGS(&backBuffer));
    if (FAILED(hr)) { dbg_hr(FN, L"SwapChain::GetBuffer", hr); return hr; }

    hr = g_d3dDevice->CreateRenderTargetView(backBuffer.Get(), nullptr, &g_rtv);
    if (FAILED(hr)) { dbg_hr(FN, L"CreateRenderTargetView", hr); return hr; }

    dbg_step(FN, L"ok");
    return S_OK;
}

static HRESULT InitD3D11AndSwapChainForComposition()
{
    const wchar_t* FN = L"InitD3D11AndSwapChainForComposition";
    dbg_step(FN, L"begin");

    UINT deviceFlags = D3D11_CREATE_DEVICE_BGRA_SUPPORT; // IMPORTANT for composition
#if defined(_DEBUG)
    deviceFlags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

    D3D_FEATURE_LEVEL fls[] = { D3D_FEATURE_LEVEL_11_0 };
    D3D_FEATURE_LEVEL flOut{};

    HRESULT hr = D3D11CreateDevice(
        nullptr,
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,
        deviceFlags,
        fls, (UINT)_countof(fls),
        D3D11_SDK_VERSION,
        &g_d3dDevice,
        &flOut,
        &g_d3dCtx
    );
    if (FAILED(hr)) { dbg_hr(FN, L"D3D11CreateDevice", hr); return hr; }

    ComPtr<IDXGIDevice> dxgiDevice;
    hr = g_d3dDevice.As(&dxgiDevice);
    if (FAILED(hr)) { dbg_hr(FN, L"Device.As(IDXGIDevice)", hr); return hr; }

    ComPtr<IDXGIAdapter> adapter;
    hr = dxgiDevice->GetAdapter(&adapter);
    if (FAILED(hr)) { dbg_hr(FN, L"dxgiDevice->GetAdapter", hr); return hr; }

    ComPtr<IDXGIFactory2> factory;
    hr = adapter->GetParent(IID_PPV_ARGS(&factory));
    if (FAILED(hr)) { dbg_hr(FN, L"adapter->GetParent(IDXGIFactory2)", hr); return hr; }

    DXGI_SWAP_CHAIN_DESC1 desc{};
    desc.Width = g_width;
    desc.Height = g_height;
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 2;
    desc.Scaling = DXGI_SCALING_STRETCH;
    desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    desc.AlphaMode = DXGI_ALPHA_MODE_IGNORE;

    hr = factory->CreateSwapChainForComposition(g_d3dDevice.Get(), &desc, nullptr, &g_swapChain);
    if (FAILED(hr)) { dbg_hr(FN, L"CreateSwapChainForComposition", hr); return hr; }

    hr = CreateRenderTarget();
    if (FAILED(hr)) return hr;

    ComPtr<ID3DBlob> vsBlob, psBlob;
    hr = Compile(kVS_HLSL, "main", "vs_4_0", vsBlob);
    if (FAILED(hr)) return hr;

    hr = Compile(kPS_HLSL, "main", "ps_4_0", psBlob);
    if (FAILED(hr)) return hr;

    hr = g_d3dDevice->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, &g_vs);
    if (FAILED(hr)) { dbg_hr(FN, L"CreateVertexShader", hr); return hr; }

    hr = g_d3dDevice->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, &g_ps);
    if (FAILED(hr)) { dbg_hr(FN, L"CreatePixelShader", hr); return hr; }

    D3D11_INPUT_ELEMENT_DESC layout[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0,  0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "COLOR",    0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };

    hr = g_d3dDevice->CreateInputLayout(
        layout, (UINT)_countof(layout),
        vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(),
        &g_inputLayout
    );
    if (FAILED(hr)) { dbg_hr(FN, L"CreateInputLayout", hr); return hr; }

    Vertex verts[3] =
    {
        {  0.0f,  0.5f, 0.5f,  1,0,0,1 },
        {  0.5f, -0.5f, 0.5f,  0,1,0,1 },
        { -0.5f, -0.5f, 0.5f,  0,0,1,1 },
    };

    D3D11_BUFFER_DESC bd{};
    bd.Usage = D3D11_USAGE_DEFAULT;
    bd.ByteWidth = sizeof(verts);
    bd.BindFlags = D3D11_BIND_VERTEX_BUFFER;

    D3D11_SUBRESOURCE_DATA init{};
    init.pSysMem = verts;

    hr = g_d3dDevice->CreateBuffer(&bd, &init, &g_vb);
    if (FAILED(hr)) { dbg_hr(FN, L"CreateBuffer(VB)", hr); return hr; }

    dbg_step(FN, L"ok");
    return S_OK;
}

// ------------------------------------------------------------
// Composition init for HWND
// ------------------------------------------------------------
static HRESULT InitCompositionForHwnd()
{
    const wchar_t* FN = L"InitCompositionForHwnd";
    dbg_step(FN, L"begin");

    if (!g_hwnd || !IsWindow(g_hwnd))
    {
        dbg_step(FN, L"HWND invalid (IsWindow==false)");
        return E_INVALIDARG;
    }

    // 1) COM STA (explicit)
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(hr))
    {
        g_comInitialized = true;
        dbg_step(FN, L"CoInitializeEx(STA) ok");
    }
    else if (hr == RPC_E_CHANGED_MODE)
    {
        // Already initialized in MTA etc. Keep going, but note it.
        dbg_step(FN, L"CoInitializeEx returned RPC_E_CHANGED_MODE (continuing)");
    }
    else
    {
        dbg_hr(FN, L"CoInitializeEx(STA)", hr);
        return hr;
    }

    // 2) DispatcherQueue MUST exist before certain Composition calls on desktop
    hr = InitDispatcherQueueForCurrentThread();
    if (FAILED(hr)) return hr;

    // 3) WinRT apartment (C++/WinRT)
    winrt::init_apartment(winrt::apartment_type::single_threaded);
    dbg_step(FN, L"winrt::init_apartment(STA) ok");

    // 4) Compositor
    g_compositor = winrt::Windows::UI::Composition::Compositor();
    dbg_step(FN, L"Compositor created");

    // Desktop interop to create DesktopWindowTarget
    auto desktopInterop = g_compositor.as<ABI::Windows::UI::Composition::Desktop::ICompositorDesktopInterop>();
    dbg_step(FN, L"ICompositorDesktopInterop acquired");

    // Use isTopMost=false (true can be rejected on some systems)
    winrt::Windows::UI::Composition::Desktop::DesktopWindowTarget target{ nullptr };
    hr = desktopInterop->CreateDesktopWindowTarget(
        g_hwnd,
        false,
        reinterpret_cast<ABI::Windows::UI::Composition::Desktop::IDesktopWindowTarget**>(winrt::put_abi(target))
    );
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateDesktopWindowTarget(hwnd,false,...)", hr);
        return hr;
    }

    g_target = target;
    dbg_step(FN, L"DesktopWindowTarget created");

    // Root visual
    g_root = g_compositor.CreateContainerVisual();
    g_target.Root(g_root);
    dbg_step(FN, L"Root visual set");

    // Interop to wrap DXGI swapchain as a composition surface
    auto compInterop = g_compositor.as<ABI::Windows::UI::Composition::ICompositorInterop>();
    dbg_step(FN, L"ICompositorInterop acquired");

    winrt::Windows::UI::Composition::ICompositionSurface surface{ nullptr };
    hr = compInterop->CreateCompositionSurfaceForSwapChain(
        g_swapChain.Get(),
        reinterpret_cast<ABI::Windows::UI::Composition::ICompositionSurface**>(winrt::put_abi(surface))
    );
    if (FAILED(hr))
    {
        dbg_hr(FN, L"CreateCompositionSurfaceForSwapChain", hr);
        return hr;
    }
    dbg_step(FN, L"CompositionSurface created for swapchain");

    // SpriteVisual to display the surface
    auto brush = g_compositor.CreateSurfaceBrush(surface);
    g_sprite = g_compositor.CreateSpriteVisual();
    g_sprite.Brush(brush);
    g_sprite.Size({ (float)g_width, (float)g_height });
    g_root.Children().InsertAtTop(g_sprite);
    dbg_step(FN, L"SpriteVisual inserted");

    dbg_step(FN, L"ok");
    return S_OK;
}

// ------------------------------------------------------------
// Render loop
// ------------------------------------------------------------
static void Render()
{
    D3D11_VIEWPORT vp{};
    vp.Width = (float)g_width;
    vp.Height = (float)g_height;
    vp.MinDepth = 0.0f;
    vp.MaxDepth = 1.0f;
    g_d3dCtx->RSSetViewports(1, &vp);

    ID3D11RenderTargetView* rtvs[] = { g_rtv.Get() };
    g_d3dCtx->OMSetRenderTargets(1, rtvs, nullptr);

    float clear[4] = { 1,1,1,1 };
    g_d3dCtx->ClearRenderTargetView(g_rtv.Get(), clear);

    UINT stride = sizeof(Vertex);
    UINT offset = 0;
    ID3D11Buffer* vbs[] = { g_vb.Get() };

    g_d3dCtx->IASetInputLayout(g_inputLayout.Get());
    g_d3dCtx->IASetVertexBuffers(0, 1, vbs, &stride, &offset);
    g_d3dCtx->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    g_d3dCtx->VSSetShader(g_vs.Get(), nullptr, 0);
    g_d3dCtx->PSSetShader(g_ps.Get(), nullptr, 0);

    g_d3dCtx->Draw(3, 0);

    // Present swapchain (composition will pick it up)
    g_swapChain->Present(1, 0);
}

// ------------------------------------------------------------
// Cleanup
// ------------------------------------------------------------
static void Cleanup()
{
    dbg_step(L"Cleanup", L"begin");

    // Release WinRT composition
    g_sprite = nullptr;
    g_root = nullptr;
    g_target = nullptr;
    g_compositor = nullptr;

    // Release D3D
    g_vb.Reset();
    g_inputLayout.Reset();
    g_ps.Reset();
    g_vs.Reset();
    g_rtv.Reset();
    g_swapChain.Reset();
    g_d3dCtx.Reset();
    g_d3dDevice.Reset();

    // DispatcherQueue controller
    if (g_dqController)
    {
        g_dqController->Release();
        g_dqController = nullptr;
    }

    // WinRT apartment
    winrt::uninit_apartment();

    // COM uninit only if we init'd it successfully
    if (g_comInitialized)
    {
        CoUninitialize();
        g_comInitialized = false;
    }

    dbg_step(L"Cleanup", L"ok");
}

// ------------------------------------------------------------
// Entry point
// ------------------------------------------------------------
int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE, PWSTR, int)
{
    dbg_step(L"wWinMain", L"start");

    HRESULT hr = CreateAppWindow(hInst);
    if (FAILED(hr))
    {
        dbgprintf(L"[FATAL] CreateAppWindow failed hr=0x%08X (abort)\n", (uint32_t)hr);
        Cleanup();
        return (int)hr;
    }

    dbg_step(L"wWinMain", L"InitD3D11...");
    hr = InitD3D11AndSwapChainForComposition();
    if (FAILED(hr))
    {
        dbgprintf(L"[FATAL] InitD3D11 failed hr=0x%08X (abort)\n", (uint32_t)hr);
        Cleanup();
        return (int)hr;
    }

    dbg_step(L"wWinMain", L"InitComposition...");
    hr = InitCompositionForHwnd();
    if (FAILED(hr))
    {
        dbgprintf(L"[FATAL] InitComposition failed hr=0x%08X (abort)\n", (uint32_t)hr);
        Cleanup();
        return (int)hr;
    }

    dbg_step(L"wWinMain", L"enter loop");
    MSG msg{};
    while (msg.message != WM_QUIT)
    {
        if (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        else
        {
            Render();
        }
    }

    dbg_step(L"wWinMain", L"loop end");
    Cleanup();
    return 0;
}
