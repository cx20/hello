// forked from https://github.com/evilrat666/directx-d/blob/master/examples/direct2d/source/boxsample.d

import std.utf;
import std.stdio;

import directx.com;
import directx.win32;
import directx.d2d1;
import directx.d2d1helper;

enum GWLP_USERDATA = -21;
enum GWLP_HINSTANCE = -6;
extern(Windows) LONG SetWindowLongA( HWND hWnd, int nIndex, LONG dwNewLong ) nothrow;
extern(Windows) LONG GetWindowLongA( HWND hWnd, int nIndex ) nothrow;

struct tagCREATESTRUCT {
    LPVOID    lpCreateParams;
    HINSTANCE hInstance;
    HMENU     hMenu;
    HWND      hwndParent;
    int       cy;
    int       cx;
    int       y;
    int       x;
    LONG      style;
    LPCTSTR   lpszName;
    LPCTSTR   lpszClass;
    DWORD     dwExStyle;
}
alias CREATESTRUCT = tagCREATESTRUCT;
alias LPCREATESTRUCT = tagCREATESTRUCT*;

void SafeRelease(T : IUnknown)(ref T ppInterfaceToRelease)
{
    if (ppInterfaceToRelease !is null)
    {
        ppInterfaceToRelease.Release();

        ppInterfaceToRelease = null;
    }
}

class HelloApp
{
public:
    ~this()
    {
        SafeRelease(m_pDirect2dFactory);
        SafeRelease(m_pRenderTarget);
        SafeRelease(m_pBlueBrush);
    }

    HRESULT Initialize()
    {
        HRESULT hr;
        HINSTANCE hinst = GetModuleHandle(null);

        hr = CreateDeviceIndependentResources();

        if (SUCCEEDED(hr))
        {

            HINSTANCE hInst = GetModuleHandle(null);
            WNDCLASS  wc;

            wc.lpszClassName = "D2DHelloApp";
            wc.style         = CS_HREDRAW | CS_VREDRAW;
            wc.lpfnWndProc   = &HelloApp.WndProc;
            wc.hInstance     = hinst;
            wc.hIcon         = LoadIcon(null, IDI_APPLICATION);
            wc.hCursor       = LoadCursor(null, IDC_CROSS);
            wc.hbrBackground = null;
            wc.lpszMenuName  = null;
            wc.cbClsExtra    = wc.cbWndExtra = LONG_PTR.sizeof;
            
            auto wca = RegisterClass(&wc);
            assert(wca);

            FLOAT dpiX, dpiY;

            m_pDirect2dFactory.ReloadSystemMetrics();
            m_pDirect2dFactory.GetDesktopDpi(&dpiX, &dpiY);

            m_hwnd = CreateWindow("D2DHelloApp", 
                                 "Hello, World!", 
                                 WS_OVERLAPPEDWINDOW,
                                 CW_USEDEFAULT, 
                                 CW_USEDEFAULT, 
                                 640, 
                                 480, 
                                 null,
                                 null, 
                                 hinst,
                                 cast(void*)this
                                 );
            
            ShowWindow(m_hwnd, SW_SHOWNORMAL);
            UpdateWindow(m_hwnd);
        }

        return hr;
    }

    void RunMessageLoop()
    {
        MSG msg;

        while (GetMessage(&msg, null, 0, 0))
        {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
    }

private:
    HRESULT CreateDeviceIndependentResources()
    {
        HRESULT hr = S_OK;

        hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &IID_ID2D1Factory, null, cast(void**)&m_pDirect2dFactory);
        return hr;
    }

    HRESULT CreateDeviceResources()
    {
        HRESULT hr = S_OK;

        if (!m_pRenderTarget)
        {
            RECT rc;
            GetClientRect(m_hwnd, &rc);

            D2D1_SIZE_U size = D2D1.SizeU(rc.right - rc.left, rc.bottom - rc.top);

            hr = m_pDirect2dFactory.CreateHwndRenderTarget(
                D2D1.RenderTargetPropertiesPtr(),
                D2D1.HwndRenderTargetPropertiesPtr(m_hwnd, size),
                &m_pRenderTarget
                );

            hr = CreateSolidColorBrush(m_pRenderTarget, D2D1.ColorF(D2D1.ColorF.CornflowerBlue), &m_pBlueBrush);
        }

        return hr;
    }

    void DiscardDeviceResources()
    {
        SafeRelease(m_pRenderTarget);
        SafeRelease(m_pBlueBrush);
    }

    HRESULT OnRender()
    {
        HRESULT hr = S_OK;

        CreateDeviceResources();
    
        m_pRenderTarget.BeginDraw();

        m_pRenderTarget.Clear(&D2D1.ColorF(D2D1.ColorF.White).color);

        int WIDTH  = 640;
        int HEIGHT = 480;

        D2D1_POINT_2F p1 = D2D1.Point2F(WIDTH * 1 / 2, HEIGHT * 1 / 4);
        D2D1_POINT_2F p2 = D2D1.Point2F(WIDTH * 3 / 4, HEIGHT * 3 / 4);
        D2D1_POINT_2F p3 = D2D1.Point2F(WIDTH * 1 / 4, HEIGHT * 3 / 4);

        m_pRenderTarget.DrawLine(p1, p2, m_pBlueBrush);
        m_pRenderTarget.DrawLine(p2, p3, m_pBlueBrush);
        m_pRenderTarget.DrawLine(p3, p1, m_pBlueBrush);

        hr = m_pRenderTarget.EndDraw();

        return hr;
    }

    nothrow extern(Windows) 
    static LRESULT WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam)
    {
        LRESULT result = 0;

        if (message == WM_CREATE)
        {
            LPCREATESTRUCT pcs = cast(LPCREATESTRUCT)lParam;
            HelloApp pHelloApp = cast(HelloApp)pcs.lpCreateParams;

            SetWindowLong(hWnd, GWLP_USERDATA, cast(int)cast(void*)pHelloApp);

            result = 1;
        }
        else
        {
            HelloApp pHelloApp = cast(HelloApp)cast(void*)(GetWindowLong(hWnd, GWLP_USERDATA));

            bool wasHandled = false;

            switch (message)
            {
                case WM_PAINT:
                    {
                        try {
                            pHelloApp.OnRender();
                            ValidateRect(hWnd, null);
                        }
                        catch( Exception e )
                        {
                        }
                    }
                    result = 0;
                    wasHandled = true;
                    break;

                case WM_DESTROY:
                    {
                        PostQuitMessage(0);
                    }
                    result = 1;
                    wasHandled = true;
                    break;
                    
                default:
                    break;
            }

            if (!wasHandled)
            {
                result = DefWindowProc(hWnd, message, wParam, lParam);
            }
        }

        return result;
    }

private:
    __gshared HWND m_hwnd;
    __gshared ID2D1Factory m_pDirect2dFactory;
    __gshared ID2D1HwndRenderTarget m_pRenderTarget;
    __gshared ID2D1SolidColorBrush m_pBlueBrush;
}

extern(Windows)
int WinMain(HINSTANCE /* hInstance */, HINSTANCE /* hPrevInstance */, LPSTR /* lpCmdLine */, int /* nCmdShow */)
{
    import core.runtime;
    
    Runtime.initialize();

    if (SUCCEEDED(CoInitialize(null)))
    {
        {
            HelloApp app = new HelloApp();

            if (SUCCEEDED(app.Initialize()))
            {
                app.RunMessageLoop();
            }
        }
        CoUninitialize();
    }
    
    Runtime.terminate();

    return 0;
}