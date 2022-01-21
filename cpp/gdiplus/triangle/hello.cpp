#include <windows.h>
#include <gdiplus.h>

using namespace Gdiplus;

LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
void OnPaint(HDC hdc);
void DrawTriangle(HDC hdc);

GdiplusStartupInput gdiSI;
ULONG_PTR           gdiToken;

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    WNDCLASSEX wcex;
    HWND hwnd;
    HDC hDC;
    HGLRC hRC;
    MSG msg;
    BOOL bQuit = FALSE;

    GdiplusStartup(&gdiToken, &gdiSI, NULL);

    wcex.cbSize         = sizeof(WNDCLASSEX);
    wcex.style          = CS_OWNDC;
    wcex.lpfnWndProc    = WindowProc;
    wcex.cbClsExtra     = 0;
    wcex.cbWndExtra     = 0;
    wcex.hInstance      = hInstance;
    wcex.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
    wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground  = (HBRUSH)GetStockObject(BLACK_BRUSH);
    wcex.lpszMenuName   = NULL;
    wcex.lpszClassName  = "WindowClass";
    wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    if (!RegisterClassEx(&wcex))
        return 0;

    hwnd = CreateWindowEx(0,
                          "WindowClass",
                          "Hello, World!",
                          WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT,
                          CW_USEDEFAULT,
                          640,
                          480,
                          NULL,
                          NULL,
                          hInstance,
                          NULL);

    ShowWindow(hwnd, nCmdShow);

    while (!bQuit)
    {
        if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
        {
            if (msg.message == WM_QUIT)
            {
                bQuit = TRUE;
            }
            else
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
        }
    }

    DestroyWindow(hwnd);

    return msg.wParam;
}

LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    HDC hdc;
    PAINTSTRUCT ps;
    switch (uMsg)
    {
        case WM_CLOSE:
            PostQuitMessage(0);
        break;

        case WM_DESTROY:
            return 0;

        case WM_PAINT:
            hdc = BeginPaint(hWnd, &ps);
            OnPaint(hdc);
            EndPaint(hWnd, &ps);
            break;
         default:
            return DefWindowProc(hWnd, uMsg, wParam, lParam);
    }

    return 0;
}

void OnPaint(HDC hdc)
{
    DrawTriangle(hdc);
}

void DrawTriangle(HDC hdc)
{
    int WIDTH  = 640;
    int HEIGHT = 480;

    Graphics graphics(hdc);

    Point points[] = {
        Point(WIDTH*1/2, HEIGHT*1/4),
        Point(WIDTH*3/4, HEIGHT*3/4),
        Point(WIDTH*1/4, HEIGHT*3/4)
    };

    GraphicsPath path;
    path.AddLines(points, 3);

    PathGradientBrush pthGrBrush(&path);

    Color centercolor = Color(255, 255/3, 255/3, 255/3);
    pthGrBrush.SetCenterColor(centercolor);
    
    Color colors[] = {
        Color(255, 255,   0,   0),  // red
        Color(255,   0, 255,   0),  // green
        Color(255,   0,   0, 255)   // blue
    };

    int count = 3;
    pthGrBrush.SetSurroundColors(colors, &count);

    graphics.FillPath(&pthGrBrush, &path);
}
