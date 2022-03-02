import core.runtime;
import std.string;
import std.utf;

auto toUTF16z(S)(S s)
{
    return toUTFz!(const(wchar)*)(s);
}

//pragma(lib, "gdi32.lib");

import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate();
    }
    catch(Throwable o)
    {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    string appName = "HelloWin";
    HWND hwnd;
    MSG  msg;
    WNDCLASS wndclass;

    wndclass.style         = CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = &WndProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    wndclass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wndclass.hbrBackground = cast(HBRUSH)GetStockObject(WHITE_BRUSH);
    wndclass.lpszMenuName  = NULL;
    wndclass.lpszClassName = appName.toUTF16z;

    RegisterClass(&wndclass);

    hwnd = CreateWindow(appName.toUTF16z,
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

    ShowWindow(hwnd, iCmdShow);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}

extern(Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    scope (failure) assert(0);

    HDC hdc;
    PAINTSTRUCT ps;
    RECT rect;

    switch (message)
    {
        case WM_PAINT:
            hdc = BeginPaint(hwnd, &ps);
            OnPaint(hdc);
            EndPaint(hwnd, &ps);
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

void OnPaint(HDC hdc) {
    DrawTriangle(hdc);
}

void DrawTriangle(HDC hdc)
{
/*
    string strMessage = "Hello, Win32 GUI(D) World!";
    TextOut(hdc, 0, 0, strMessage.toUTF16z, strMessage.length);
*/
    int WIDTH  = 640;
    int HEIGHT = 480;

    TRIVERTEX[3] vertex;
    vertex[0].x     = WIDTH  * 1 / 2;
    vertex[0].y     = HEIGHT * 1 / 4;
    vertex[0].Red   = 0xffff;
    vertex[0].Green = 0x0000;
    vertex[0].Blue  = 0x0000;
    vertex[0].Alpha = 0x0000;

    vertex[1].x     = WIDTH  * 3 / 4;
    vertex[1].y     = HEIGHT * 3 / 4;
    vertex[1].Red   = 0x0000;
    vertex[1].Green = 0xffff;
    vertex[1].Blue  = 0x0000;
    vertex[1].Alpha = 0x0000;

    vertex[2].x     = WIDTH  * 1 / 4;
    vertex[2].y     = HEIGHT * 3 / 4;
    vertex[2].Red   = 0x0000;
    vertex[2].Green = 0x0000;
    vertex[2].Blue  = 0xffff;
    vertex[2].Alpha = 0x0000;

    GRADIENT_TRIANGLE gTriangle;
    gTriangle.Vertex1 = 0;
    gTriangle.Vertex2 = 1;
    gTriangle.Vertex3 = 2;

    GradientFill(hdc, &vertex[0], 3, &gTriangle, 1, GRADIENT_FILL_TRIANGLE);
}
