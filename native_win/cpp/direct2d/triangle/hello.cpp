#include <d2d1.h>
#include <tchar.h>

#include <wrl/client.h>
using namespace Microsoft::WRL;

LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
ComPtr<ID2D1HwndRenderTarget> CreateRenderTarget(HWND hWnd);
void Draw(ID2D1HwndRenderTarget* renderTarget);

ComPtr<ID2D1HwndRenderTarget> g_renderTarget;

int WINAPI _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    LPCTSTR lpszClassName = _T("helloWindow");
    LPCTSTR lpszWindowName = _T("Hello, World!");
 
    WNDCLASSEX wcex;
    wcex.cbSize = sizeof(WNDCLASSEX);
    wcex.style          = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc    = WndProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APPLICATION));
    wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
    wcex.lpszMenuName   = NULL;
    wcex.lpszClassName  = lpszClassName;
    wcex.hIconSm        = LoadIcon(wcex.hInstance, MAKEINTRESOURCE(IDI_APPLICATION));
 
    RegisterClassEx(&wcex);
    HWND hWnd = CreateWindow(
        lpszClassName,
        lpszWindowName,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
        NULL, NULL, hInstance, NULL
    );
 
    g_renderTarget = CreateRenderTarget(hWnd);
 
    ShowWindow(hWnd, SW_SHOWDEFAULT);
    UpdateWindow(hWnd);

    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
 
    return (int)msg.wParam;
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_PAINT:
        Draw(g_renderTarget.Get());
        return 0;
    case WM_SIZE:
        g_renderTarget->Resize(D2D1::SizeU(LOWORD(lParam), HIWORD(lParam)));
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}

ComPtr<ID2D1HwndRenderTarget> CreateRenderTarget(HWND hWnd)
{
    HRESULT hr = S_OK;

    ComPtr<ID2D1Factory> factory;
    hr = D2D1CreateFactory<ID2D1Factory>(D2D1_FACTORY_TYPE_SINGLE_THREADED, &factory);
    if( FAILED( hr ) )
        return NULL;
    
    ComPtr<ID2D1HwndRenderTarget> renderTarget;
    hr = factory->CreateHwndRenderTarget(
        D2D1::RenderTargetProperties(), 
        D2D1::HwndRenderTargetProperties(hWnd), 
        &renderTarget
    );
    
    if( FAILED( hr ) )
        return NULL;

    return renderTarget;
}

void Draw(ID2D1HwndRenderTarget* renderTarget)
{
    int WIDTH  = 640;
    int HEIGHT = 480;

    renderTarget->BeginDraw();
    renderTarget->Clear(D2D1::ColorF(D2D1::ColorF::White));

    D2D1_POINT_2F p1 = D2D1::Point2F(WIDTH * 1 / 2, HEIGHT * 1 / 4);
    D2D1_POINT_2F p2 = D2D1::Point2F(WIDTH * 3 / 4, HEIGHT * 3 / 4);
    D2D1_POINT_2F p3 = D2D1::Point2F(WIDTH * 1 / 4, HEIGHT * 3 / 4);
    
    ComPtr<ID2D1SolidColorBrush> brush;
    renderTarget->CreateSolidColorBrush(D2D1::ColorF(D2D1::ColorF::Blue), &brush);

    renderTarget->DrawLine(p1, p2, brush.Get());
    renderTarget->DrawLine(p2, p3, brush.Get());
    renderTarget->DrawLine(p3, p1, brush.Get());

    renderTarget->EndDraw();
}

