#include <windows.h>
#include <tchar.h>

typedef struct _GdiplusStartupInput
{
    unsigned int GdiplusVersion;
    unsigned int DebugEventCallback;
    BOOL SuppressBackgroundThread;
    BOOL SuppressExternalCodecs;
} GdiplusStartupInput;

typedef int INT;

typedef struct _GpPoint
{
    INT x;
    INT y;
} GpPoint;

int WINAPI GdiplusStartup(int* token, GdiplusStartupInput *input, int *output);
void WINAPI GdiplusShutdown(int token);
int WINAPI GdipCreateFromHDC(HDC hdc, int* graphics);
int WINAPI GdipDeleteGraphics(int graphics);

int WINAPI GdipCreatePath(int brushMode, int** path);
int WINAPI GdipDeletePath(int* path);
int WINAPI GdipAddPathLine2I(int* path, const GpPoint* points, int count);

int WINAPI GdipCreatePathGradientFromPath(const int* path, int** polyGradient);
int WINAPI GdipSetPathGradientCenterColor(int *brush, unsigned int argb_colors);
int WINAPI GdipSetPathGradientSurroundColorsWithCount( int *brush, unsigned int* argb_color, int* count);

int WINAPI GdipFillPath(int graphics, int* brush, int* path);

int token;
int* path;
int* brush;

LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
void OnPaint(HDC hdc);
void DrawTriangle(HDC hdc);

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    GdiplusStartupInput StartupInput = { 0 };
    StartupInput.GdiplusVersion = 1;
    GdiplusStartup(&token, &StartupInput, NULL);
    
    WNDCLASSEX wcex;
    HWND hwnd;
    HDC hDC;
    HGLRC hRC;
    MSG msg;
    BOOL bQuit = FALSE;

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

    int graphics;
    GdipCreateFromHDC(hdc, &graphics);

    GdipCreatePath(0, &path);

    GpPoint points[] = {
        {WIDTH * 1 / 2, HEIGHT * 1 / 4},
        {WIDTH * 3 / 4, HEIGHT * 3 / 4},
        {WIDTH * 1 / 4, HEIGHT * 3 / 4}
    };

    GdipAddPathLine2I(path, points, 3);
    
    GdipCreatePathGradientFromPath(path, &brush);

    GdipSetPathGradientCenterColor(brush, 0xff555555);	// Color(255, 255/3, 255/3, 255/3)

    unsigned int colors[] = {
        0xffff0000,  // red
        0xff00ff00,  // green
        0xff0000ff   // blue
    };

    int count = 3;
    GdipSetPathGradientSurroundColorsWithCount(brush, colors, &count);

    GdipFillPath(graphics, brush, path);

    GdipDeletePath(path);
    GdipDeleteGraphics(graphics);
}
