#include <windows.h>
#include <tchar.h>

#pragma comment(lib, "d2d1.lib")

typedef struct D2D1_COLOR_F {
    FLOAT r, g, b, a;
} D2D1_COLOR_F;

typedef struct D2D1_POINT_2F {
    FLOAT x, y;
} D2D1_POINT_2F;

typedef struct D2D1_SIZE_U {
    UINT32 width, height;
} D2D1_SIZE_U;

typedef struct D2D1_MATRIX_3X2_F {
    FLOAT _11, _12, _21, _22, _31, _32;
} D2D1_MATRIX_3X2_F;

typedef struct D2D1_PIXEL_FORMAT {
    UINT format;
    UINT alphaMode;
} D2D1_PIXEL_FORMAT;

typedef struct D2D1_RENDER_TARGET_PROPERTIES {
    UINT type;
    D2D1_PIXEL_FORMAT pixelFormat;
    FLOAT dpiX, dpiY;
    UINT usage;
    UINT minLevel;
} D2D1_RENDER_TARGET_PROPERTIES;

typedef struct D2D1_HWND_RENDER_TARGET_PROPERTIES {
    HWND hwnd;
    D2D1_SIZE_U pixelSize;
    UINT presentOptions;
} D2D1_HWND_RENDER_TARGET_PROPERTIES;

typedef struct D2D1_BRUSH_PROPERTIES {
    FLOAT opacity;
    D2D1_MATRIX_3X2_F transform;
} D2D1_BRUSH_PROPERTIES;

typedef struct ID2D1Factory ID2D1Factory;
typedef struct ID2D1RenderTarget ID2D1RenderTarget;
typedef struct ID2D1HwndRenderTarget ID2D1HwndRenderTarget;
typedef struct ID2D1Brush ID2D1Brush;
typedef struct ID2D1SolidColorBrush ID2D1SolidColorBrush;

typedef struct ID2D1FactoryVtbl {
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(ID2D1Factory*, REFIID, void**);
    ULONG (STDMETHODCALLTYPE *AddRef)(ID2D1Factory*);
    ULONG (STDMETHODCALLTYPE *Release)(ID2D1Factory*);
    /* ID2D1Factory */
    HRESULT (STDMETHODCALLTYPE *ReloadSystemMetrics)(ID2D1Factory*);
    void (STDMETHODCALLTYPE *GetDesktopDpi)(ID2D1Factory*, FLOAT*, FLOAT*);
    HRESULT (STDMETHODCALLTYPE *CreateRectangleGeometry)(ID2D1Factory*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateRoundedRectangleGeometry)(ID2D1Factory*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateEllipseGeometry)(ID2D1Factory*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateGeometryGroup)(ID2D1Factory*, int, void**, UINT32, void**);
    HRESULT (STDMETHODCALLTYPE *CreateTransformedGeometry)(ID2D1Factory*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreatePathGeometry)(ID2D1Factory*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateStrokeStyle)(ID2D1Factory*, void*, void*, UINT32, void**);
    HRESULT (STDMETHODCALLTYPE *CreateDrawingStateBlock)(ID2D1Factory*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateWicBitmapRenderTarget)(ID2D1Factory*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateHwndRenderTarget)(ID2D1Factory*, 
        const D2D1_RENDER_TARGET_PROPERTIES*, 
        const D2D1_HWND_RENDER_TARGET_PROPERTIES*, 
        ID2D1HwndRenderTarget**);
} ID2D1FactoryVtbl;

struct ID2D1Factory { const ID2D1FactoryVtbl *lpVtbl; };

typedef struct ID2D1HwndRenderTargetVtbl {
    /* IUnknown */
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(ID2D1HwndRenderTarget*, REFIID, void**);
    ULONG (STDMETHODCALLTYPE *AddRef)(ID2D1HwndRenderTarget*);
    ULONG (STDMETHODCALLTYPE *Release)(ID2D1HwndRenderTarget*);
    /* ID2D1Resource */
    void (STDMETHODCALLTYPE *GetFactory)(ID2D1HwndRenderTarget*, ID2D1Factory**);
    /* ID2D1RenderTarget */
    HRESULT (STDMETHODCALLTYPE *CreateBitmap)(ID2D1HwndRenderTarget*, D2D1_SIZE_U, void*, UINT32, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateBitmapFromWicBitmap)(ID2D1HwndRenderTarget*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateSharedBitmap)(ID2D1HwndRenderTarget*, REFIID, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateBitmapBrush)(ID2D1HwndRenderTarget*, void*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateSolidColorBrush)(ID2D1HwndRenderTarget*, 
        const D2D1_COLOR_F*, const D2D1_BRUSH_PROPERTIES*, ID2D1SolidColorBrush**);
    HRESULT (STDMETHODCALLTYPE *CreateGradientStopCollection)(ID2D1HwndRenderTarget*, void*, UINT32, int, int, void**);
    HRESULT (STDMETHODCALLTYPE *CreateLinearGradientBrush)(ID2D1HwndRenderTarget*, void*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateRadialGradientBrush)(ID2D1HwndRenderTarget*, void*, void*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateCompatibleRenderTarget)(ID2D1HwndRenderTarget*, void*, void*, void*, int, void**);
    HRESULT (STDMETHODCALLTYPE *CreateLayer)(ID2D1HwndRenderTarget*, void*, void**);
    HRESULT (STDMETHODCALLTYPE *CreateMesh)(ID2D1HwndRenderTarget*, void**);
    void (STDMETHODCALLTYPE *DrawLine)(ID2D1HwndRenderTarget*, D2D1_POINT_2F, D2D1_POINT_2F, ID2D1Brush*, FLOAT, void*);
    void (STDMETHODCALLTYPE *DrawRectangle)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillRectangle)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*);
    void (STDMETHODCALLTYPE *DrawRoundedRectangle)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillRoundedRectangle)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*);
    void (STDMETHODCALLTYPE *DrawEllipse)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillEllipse)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*);
    void (STDMETHODCALLTYPE *DrawGeometry)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*, FLOAT, void*);
    void (STDMETHODCALLTYPE *FillGeometry)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*, ID2D1Brush*);
    void (STDMETHODCALLTYPE *FillMesh)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*);
    void (STDMETHODCALLTYPE *FillOpacityMask)(ID2D1HwndRenderTarget*, void*, ID2D1Brush*, int, void*, void*);
    void (STDMETHODCALLTYPE *DrawBitmap)(ID2D1HwndRenderTarget*, void*, void*, FLOAT, int, void*);
    void (STDMETHODCALLTYPE *DrawTextW)(ID2D1HwndRenderTarget*, void*, UINT32, void*, void*, ID2D1Brush*, int, int);
    void (STDMETHODCALLTYPE *DrawTextLayout)(ID2D1HwndRenderTarget*, D2D1_POINT_2F, void*, ID2D1Brush*, int);
    void (STDMETHODCALLTYPE *DrawGlyphRun)(ID2D1HwndRenderTarget*, D2D1_POINT_2F, void*, ID2D1Brush*, int);
    void (STDMETHODCALLTYPE *SetTransform)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *GetTransform)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *SetAntialiasMode)(ID2D1HwndRenderTarget*, int);
    int (STDMETHODCALLTYPE *GetAntialiasMode)(ID2D1HwndRenderTarget*);
    void (STDMETHODCALLTYPE *SetTextAntialiasMode)(ID2D1HwndRenderTarget*, int);
    int (STDMETHODCALLTYPE *GetTextAntialiasMode)(ID2D1HwndRenderTarget*);
    void (STDMETHODCALLTYPE *SetTextRenderingParams)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *GetTextRenderingParams)(ID2D1HwndRenderTarget*, void**);
    void (STDMETHODCALLTYPE *SetTags)(ID2D1HwndRenderTarget*, UINT64, UINT64);
    void (STDMETHODCALLTYPE *GetTags)(ID2D1HwndRenderTarget*, UINT64*, UINT64*);
    void (STDMETHODCALLTYPE *PushLayer)(ID2D1HwndRenderTarget*, void*, void*);
    void (STDMETHODCALLTYPE *PopLayer)(ID2D1HwndRenderTarget*);
    HRESULT (STDMETHODCALLTYPE *Flush)(ID2D1HwndRenderTarget*, UINT64*, UINT64*);
    void (STDMETHODCALLTYPE *SaveDrawingState)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *RestoreDrawingState)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *PushAxisAlignedClip)(ID2D1HwndRenderTarget*, void*, int);
    void (STDMETHODCALLTYPE *PopAxisAlignedClip)(ID2D1HwndRenderTarget*);
    void (STDMETHODCALLTYPE *Clear)(ID2D1HwndRenderTarget*, const D2D1_COLOR_F*);
    void (STDMETHODCALLTYPE *BeginDraw)(ID2D1HwndRenderTarget*);
    HRESULT (STDMETHODCALLTYPE *EndDraw)(ID2D1HwndRenderTarget*, UINT64*, UINT64*);
    void (STDMETHODCALLTYPE *GetPixelFormat)(ID2D1HwndRenderTarget*, D2D1_PIXEL_FORMAT*);
    void (STDMETHODCALLTYPE *SetDpi)(ID2D1HwndRenderTarget*, FLOAT, FLOAT);
    void (STDMETHODCALLTYPE *GetDpi)(ID2D1HwndRenderTarget*, FLOAT*, FLOAT*);
    void (STDMETHODCALLTYPE *GetSize)(ID2D1HwndRenderTarget*, void*);
    void (STDMETHODCALLTYPE *GetPixelSize)(ID2D1HwndRenderTarget*, D2D1_SIZE_U*);
    UINT32 (STDMETHODCALLTYPE *GetMaximumBitmapSize)(ID2D1HwndRenderTarget*);
    BOOL (STDMETHODCALLTYPE *IsSupported)(ID2D1HwndRenderTarget*, void*);
    /* ID2D1HwndRenderTarget */
    int (STDMETHODCALLTYPE *CheckWindowState)(ID2D1HwndRenderTarget*);
    HRESULT (STDMETHODCALLTYPE *Resize)(ID2D1HwndRenderTarget*, const D2D1_SIZE_U*);
    HWND (STDMETHODCALLTYPE *GetHwnd)(ID2D1HwndRenderTarget*);
} ID2D1HwndRenderTargetVtbl;

struct ID2D1HwndRenderTarget { const ID2D1HwndRenderTargetVtbl *lpVtbl; };

typedef struct ID2D1SolidColorBrushVtbl {
    HRESULT (STDMETHODCALLTYPE *QueryInterface)(ID2D1SolidColorBrush*, REFIID, void**);
    ULONG (STDMETHODCALLTYPE *AddRef)(ID2D1SolidColorBrush*);
    ULONG (STDMETHODCALLTYPE *Release)(ID2D1SolidColorBrush*);
} ID2D1SolidColorBrushVtbl;

struct ID2D1SolidColorBrush { const ID2D1SolidColorBrushVtbl *lpVtbl; };

/* IID */
static const GUID IID_ID2D1Factory = 
    { 0x06152247, 0x6f50, 0x465a, { 0x92, 0x45, 0x11, 0x8b, 0xfd, 0x3b, 0x60, 0x07 } };

/* D2D1CreateFactory */
typedef HRESULT (WINAPI *PFN_D2D1CreateFactory)(UINT, REFIID, const void*, void**);

ID2D1HwndRenderTarget* g_renderTarget = NULL;
HMODULE g_hD2D1 = NULL;

LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
ID2D1HwndRenderTarget* CreateRenderTarget(HWND hWnd);
void Draw(ID2D1HwndRenderTarget* renderTarget);

/* ===== WinMain ===== */

int WINAPI _tWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPTSTR lpCmdLine, int nCmdShow)
{
    LPCTSTR lpszClassName = _T("helloWindow");
    LPCTSTR lpszWindowName = _T("Hello, World!");
    WNDCLASSEX wcex;
    HWND hWnd;
    MSG msg;

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
    hWnd = CreateWindow(
        lpszClassName, lpszWindowName, WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
        NULL, NULL, hInstance, NULL
    );

    g_renderTarget = CreateRenderTarget(hWnd);
    if (!g_renderTarget) {
        MessageBox(NULL, _T("Failed to create render target"), _T("Error"), MB_OK);
        return 1;
    }

    ShowWindow(hWnd, SW_SHOWDEFAULT);
    UpdateWindow(hWnd);

    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    if (g_renderTarget) {
        g_renderTarget->lpVtbl->Release(g_renderTarget);
        g_renderTarget = NULL;
    }
    if (g_hD2D1) {
        FreeLibrary(g_hD2D1);
    }

    return (int)msg.wParam;
}

/* ===== WndProc ===== */

LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg) {
    case WM_PAINT:
        if (g_renderTarget) Draw(g_renderTarget);
        ValidateRect(hWnd, NULL);
        return 0;
    case WM_SIZE:
        if (g_renderTarget) {
            D2D1_SIZE_U size = { LOWORD(lParam), HIWORD(lParam) };
            g_renderTarget->lpVtbl->Resize(g_renderTarget, &size);
        }
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}

/* ===== CreateRenderTarget ===== */

ID2D1HwndRenderTarget* CreateRenderTarget(HWND hWnd)
{
    HRESULT hr;
    ID2D1Factory* factory = NULL;
    ID2D1HwndRenderTarget* renderTarget = NULL;
    PFN_D2D1CreateFactory pfnD2D1CreateFactory;
    D2D1_RENDER_TARGET_PROPERTIES rtProps;
    D2D1_HWND_RENDER_TARGET_PROPERTIES hwndProps;

    g_hD2D1 = LoadLibrary(_T("d2d1.dll"));
    if (!g_hD2D1) return NULL;

    pfnD2D1CreateFactory = (PFN_D2D1CreateFactory)GetProcAddress(g_hD2D1, "D2D1CreateFactory");
    if (!pfnD2D1CreateFactory) return NULL;

    hr = pfnD2D1CreateFactory(0, &IID_ID2D1Factory, NULL, (void**)&factory);
    if (FAILED(hr)) return NULL;

    rtProps.type = 0;
    rtProps.pixelFormat.format = 0;
    rtProps.pixelFormat.alphaMode = 0;
    rtProps.dpiX = 0.0f;
    rtProps.dpiY = 0.0f;
    rtProps.usage = 0;
    rtProps.minLevel = 0;

    hwndProps.hwnd = hWnd;
    hwndProps.pixelSize.width = 0;
    hwndProps.pixelSize.height = 0;
    hwndProps.presentOptions = 0;

    hr = factory->lpVtbl->CreateHwndRenderTarget(factory, &rtProps, &hwndProps, &renderTarget);
    factory->lpVtbl->Release(factory);

    if (FAILED(hr)) return NULL;
    return renderTarget;
}

/* ===== Draw ===== */

void Draw(ID2D1HwndRenderTarget* renderTarget)
{
    D2D1_COLOR_F clearColor = { 1.0f, 1.0f, 1.0f, 1.0f };
    D2D1_COLOR_F blueColor  = { 0.0f, 0.0f, 1.0f, 1.0f };
    D2D1_POINT_2F p1 = { 320.0f, 120.0f };
    D2D1_POINT_2F p2 = { 480.0f, 360.0f };
    D2D1_POINT_2F p3 = { 160.0f, 360.0f };
    ID2D1SolidColorBrush* brush = NULL;

    renderTarget->lpVtbl->BeginDraw(renderTarget);
    renderTarget->lpVtbl->Clear(renderTarget, &clearColor);
    renderTarget->lpVtbl->CreateSolidColorBrush(renderTarget, &blueColor, NULL, &brush);

    if (brush) {
        renderTarget->lpVtbl->DrawLine(renderTarget, p1, p2, (ID2D1Brush*)brush, 1.0f, NULL);
        renderTarget->lpVtbl->DrawLine(renderTarget, p2, p3, (ID2D1Brush*)brush, 1.0f, NULL);
        renderTarget->lpVtbl->DrawLine(renderTarget, p3, p1, (ID2D1Brush*)brush, 1.0f, NULL);
        brush->lpVtbl->Release(brush);
    }

    renderTarget->lpVtbl->EndDraw(renderTarget, NULL, NULL);
}