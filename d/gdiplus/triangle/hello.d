import core.runtime;
import std.string;
import std.utf;

auto toUTF16z(S)(S s)
{
    return toUTFz!(const(wchar)*)(s);
}

import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.wingdi;
import core.sys.windows.winbase;

// GDI+ bindings
alias GpStatus = int;
alias GpGraphics = void*;
alias GpBrush = void*;
alias GpSolidFill = void*;
alias GpPen = void*;
alias GpPath = void*;
alias GpPathGradient = void*;
alias ARGB = uint;
alias REAL = float;

struct GdiplusStartupInput
{
    uint GdiplusVersion = 1;
    void* DebugEventCallback;
    int SuppressBackgroundThread;
    int SuppressExternalCodecs;
}

struct GdiplusStartupOutput
{
    void* NotificationHook;
    void* NotificationUnhook;
}

struct GpPointF
{
    REAL X;
    REAL Y;
}

struct GpPoint
{
    int X;
    int Y;
}

// GDI+ functions from gdiplus.dll
extern(Windows) nothrow @nogc
{
    GpStatus GdiplusStartup(ulong* token, GdiplusStartupInput* input, GdiplusStartupOutput* output);
    void GdiplusShutdown(ulong token);
    GpStatus GdipCreateFromHDC(HDC hdc, GpGraphics* graphics);
    GpStatus GdipDeleteGraphics(GpGraphics graphics);
    GpStatus GdipCreateSolidFill(ARGB color, GpSolidFill* brush);
    GpStatus GdipDeleteBrush(GpBrush brush);
    GpStatus GdipFillPolygonI(GpGraphics graphics, GpBrush brush, GpPoint* points, int count, int fillMode);
    GpStatus GdipCreatePen1(ARGB color, REAL width, int unit, GpPen* pen);
    GpStatus GdipDeletePen(GpPen pen);
    GpStatus GdipDrawPolygonI(GpGraphics graphics, GpPen pen, GpPoint* points, int count);
    GpStatus GdipSetSmoothingMode(GpGraphics graphics, int smoothingMode);
    
    // GraphicsPath functions
    GpStatus GdipCreatePath(int brushMode, GpPath* path);
    GpStatus GdipDeletePath(GpPath path);
    GpStatus GdipAddPathLine2I(GpPath path, GpPoint* points, int count);
    GpStatus GdipClosePathFigure(GpPath path);
    
    // PathGradientBrush functions
    GpStatus GdipCreatePathGradientI(GpPoint* points, int count, int wrapMode, GpPathGradient* polyGradient);
    GpStatus GdipSetPathGradientCenterColor(GpPathGradient brush, ARGB colors);
    GpStatus GdipSetPathGradientSurroundColorsWithCount(GpPathGradient brush, ARGB* color, int* count);
    
    // FillPath function
    GpStatus GdipFillPath(GpGraphics graphics, GpBrush brush, GpPath path);
}

// GDI+ constants
enum FillModeAlternate = 0;
enum UnitPixel = 2;
enum SmoothingModeAntiAlias = 4;
enum WrapModeClamp = 4;

// Helper to create ARGB color
ARGB makeARGB(ubyte a, ubyte r, ubyte g, ubyte b) nothrow @nogc
{
    return (cast(ARGB)a << 24) | (cast(ARGB)r << 16) | (cast(ARGB)g << 8) | b;
}

__gshared ulong gdiplusToken;

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;

    try
    {
        Runtime.initialize();
        
        // Initialize GDI+
        GdiplusStartupInput gdiplusStartupInput;
        GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, null);
        
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        
        // Shutdown GDI+
        GdiplusShutdown(gdiplusToken);
        
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
    string appName = "GDIPlusTriangle";
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
                         "GDI+ Triangle - D Language",
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

    return cast(int)msg.wParam;
}

extern(Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    scope (failure) assert(0);

    HDC hdc;
    PAINTSTRUCT ps;

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

void OnPaint(HDC hdc) nothrow @nogc
{
    DrawTriangle(hdc);
}

void DrawTriangle(HDC hdc) nothrow @nogc
{
    int WIDTH  = 640;
    int HEIGHT = 480;

    GpGraphics graphics;
    GdipCreateFromHDC(hdc, &graphics);
    
    // Enable anti-aliasing
    GdipSetSmoothingMode(graphics, SmoothingModeAntiAlias);

    // Define triangle points
    GpPoint[3] points;
    points[0].X = WIDTH  * 1 / 2;
    points[0].Y = HEIGHT * 1 / 4;
    points[1].X = WIDTH  * 3 / 4;
    points[1].Y = HEIGHT * 3 / 4;
    points[2].X = WIDTH  * 1 / 4;
    points[2].Y = HEIGHT * 3 / 4;

    // Create PathGradientBrush from points
    GpPathGradient pthGrBrush;
    GdipCreatePathGradientI(&points[0], 3, WrapModeClamp, &pthGrBrush);

    // Set center color (average of RGB)
    ARGB centerColor = makeARGB(255, 255/3, 255/3, 255/3);
    GdipSetPathGradientCenterColor(pthGrBrush, centerColor);

    // Set surround colors (vertex colors)
    ARGB[3] colors;
    colors[0] = makeARGB(255, 255,   0,   0);  // red
    colors[1] = makeARGB(255,   0, 255,   0);  // green
    colors[2] = makeARGB(255,   0,   0, 255);  // blue
    int count = 3;
    GdipSetPathGradientSurroundColorsWithCount(pthGrBrush, &colors[0], &count);

    // Create path and add polygon
    GpPath path;
    GdipCreatePath(FillModeAlternate, &path);
    GdipAddPathLine2I(path, &points[0], 3);
    GdipClosePathFigure(path);

    // Fill the path with gradient brush
    GdipFillPath(graphics, pthGrBrush, path);

    // Cleanup
    GdipDeletePath(path);
    GdipDeleteBrush(pthGrBrush);
    GdipDeleteGraphics(graphics);
}