#include <windows.h>
#include <tchar.h>
#include <stdio.h>

typedef struct _GdiplusStartupInput
{
    unsigned int GdiplusVersion;
    void* DebugEventCallback;
    BOOL SuppressBackgroundThread;
    BOOL SuppressExternalCodecs;
} GdiplusStartupInput;

typedef int INT;

typedef struct _GpPoint
{
    INT x;
    INT y;
} GpPoint;

typedef void* GpGraphics;
typedef void* GpPath;
typedef void* GpBrush;

int WINAPI GdiplusStartup(ULONG_PTR* token, GdiplusStartupInput *input, void *output);
void WINAPI GdiplusShutdown(ULONG_PTR token);
int WINAPI GdipCreateFromHDC(HDC hdc, GpGraphics* graphics);
int WINAPI GdipDeleteGraphics(GpGraphics graphics);

int WINAPI GdipCreatePath(int brushMode, GpPath* path);
int WINAPI GdipDeletePath(GpPath path);
int WINAPI GdipAddPathLine2I(GpPath path, const GpPoint* points, int count);
int WINAPI GdipClosePathFigure(GpPath path);

int WINAPI GdipCreatePathGradientFromPath(GpPath path, GpBrush* polyGradient);
int WINAPI GdipSetPathGradientCenterColor(GpBrush brush, unsigned int argb_colors);
int WINAPI GdipSetPathGradientSurroundColorsWithCount(GpBrush brush, unsigned int* argb_color, int* count);
int WINAPI GdipDeleteBrush(GpBrush brush);

int WINAPI GdipFillPath(GpGraphics graphics, GpBrush brush, GpPath path);

ULONG_PTR token;

void DebugLog(const char* funcName, int status)
{
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "[DEBUG] %s: status = %d %s\n", 
             funcName, status, (status == 0) ? "(Ok)" : "(FAILED)");
    OutputDebugStringA(buffer);
}

void DebugLogPtr(const char* funcName, int status, void* ptr)
{
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "[DEBUG] %s: status = %d %s, ptr = %p\n", 
             funcName, status, (status == 0) ? "(Ok)" : "(FAILED)", ptr);
    OutputDebugStringA(buffer);
}

void DebugMsg(const char* msg)
{
    char buffer[256];
    snprintf(buffer, sizeof(buffer), "[DEBUG] %s\n", msg);
    OutputDebugStringA(buffer);
}

LRESULT CALLBACK WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
void OnPaint(HDC hdc);
void DrawTriangle(HDC hdc);

int APIENTRY _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    int status;
    GdiplusStartupInput StartupInput = { 0 };
    StartupInput.GdiplusVersion = 1;
    
    status = GdiplusStartup(&token, &StartupInput, NULL);
    DebugLog("GdiplusStartup", status);
    
    if (status != 0)
    {
        MessageBoxA(NULL, "GDI+ initialization failed!", "Error", MB_OK | MB_ICONERROR);
        return 0;
    }
    
    WNDCLASSEX wcex;
    HWND hwnd;
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
    wcex.hbrBackground  = (HBRUSH)GetStockObject(WHITE_BRUSH);
    wcex.lpszMenuName   = NULL;
    wcex.lpszClassName  = "WindowClass";
    wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    if (!RegisterClassEx(&wcex))
    {
        DebugMsg("RegisterClassEx FAILED");
        return 0;
    }
    DebugMsg("RegisterClassEx OK");

    hwnd = CreateWindowEx(0,
                          "WindowClass",
                          "GDI+ Triangle - C Language",
                          WS_OVERLAPPEDWINDOW,
                          CW_USEDEFAULT,
                          CW_USEDEFAULT,
                          640,
                          480,
                          NULL,
                          NULL,
                          hInstance,
                          NULL);

    if (hwnd == NULL)
    {
        DebugMsg("CreateWindowEx FAILED");
        return 0;
    }
    DebugMsg("CreateWindowEx OK");

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

    GdiplusShutdown(token);
    DebugMsg("GdiplusShutdown called");

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
            DebugMsg("WM_PAINT received");
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
    DebugMsg("OnPaint called");
    DrawTriangle(hdc);
}

void DrawTriangle(HDC hdc)
{
    int status;
    int WIDTH  = 640;
    int HEIGHT = 480;

    GpGraphics graphics = NULL;
    GpPath path = NULL;
    GpBrush brush = NULL;

    DebugMsg("DrawTriangle started");

    status = GdipCreateFromHDC(hdc, &graphics);
    DebugLogPtr("GdipCreateFromHDC", status, graphics);
    if (status != 0) return;

    status = GdipCreatePath(0, &path);
    DebugLogPtr("GdipCreatePath", status, path);
    if (status != 0) goto cleanup_graphics;

    GpPoint points[] = {
        {WIDTH * 1 / 2, HEIGHT * 1 / 4},
        {WIDTH * 3 / 4, HEIGHT * 3 / 4},
        {WIDTH * 1 / 4, HEIGHT * 3 / 4}
    };

    {
        char buffer[256];
        snprintf(buffer, sizeof(buffer), "[DEBUG] Points: (%d,%d), (%d,%d), (%d,%d)\n",
                 points[0].x, points[0].y, points[1].x, points[1].y, points[2].x, points[2].y);
        OutputDebugStringA(buffer);
    }

    status = GdipAddPathLine2I(path, points, 3);
    DebugLog("GdipAddPathLine2I", status);
    if (status != 0) goto cleanup_path;

    status = GdipClosePathFigure(path);
    DebugLog("GdipClosePathFigure", status);
    if (status != 0) goto cleanup_path;
    
    status = GdipCreatePathGradientFromPath(path, &brush);
    DebugLogPtr("GdipCreatePathGradientFromPath", status, brush);
    if (status != 0) goto cleanup_path;

    status = GdipSetPathGradientCenterColor(brush, 0xff555555);
    DebugLog("GdipSetPathGradientCenterColor", status);

    unsigned int colors[] = {
        0xffff0000,  // red
        0xff00ff00,  // green
        0xff0000ff   // blue
    };

    int count = 3;
    status = GdipSetPathGradientSurroundColorsWithCount(brush, colors, &count);
    DebugLog("GdipSetPathGradientSurroundColorsWithCount", status);

    status = GdipFillPath(graphics, brush, path);
    DebugLog("GdipFillPath", status);

    GdipDeleteBrush(brush);
    DebugMsg("GdipDeleteBrush called");

cleanup_path:
    GdipDeletePath(path);
    DebugMsg("GdipDeletePath called");

cleanup_graphics:
    GdipDeleteGraphics(graphics);
    DebugMsg("GdipDeleteGraphics called");

    DebugMsg("DrawTriangle finished");
}