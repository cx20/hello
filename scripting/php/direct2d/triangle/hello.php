<?php
declare(strict_types=1);

/*
  Direct2D Triangle Drawing via PHP FFI
  
  Uses Direct2D COM interfaces via vtable (early binding).
  Draws a blue triangle outline using DrawLine.
*/

// Window styles
const WS_OVERLAPPED       = 0x00000000;
const WS_CAPTION          = 0x00C00000;
const WS_SYSMENU          = 0x00080000;
const WS_THICKFRAME       = 0x00040000;
const WS_MINIMIZEBOX      = 0x00020000;
const WS_MAXIMIZEBOX      = 0x00010000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

const CS_HREDRAW          = 0x0002;
const CS_VREDRAW          = 0x0001;
const CW_USEDEFAULT       = 0x80000000;
const SW_SHOWDEFAULT      = 10;
const COLOR_WINDOW        = 5;

const WM_QUIT             = 0x0012;
const WM_PAINT            = 0x000F;
const WM_SIZE             = 0x0005;
const PM_REMOVE           = 0x0001;

const IDI_APPLICATION     = 32512;
const IDC_ARROW           = 32512;

// D2D1 vtable indices
const VTBL_RELEASE = 2;

// ID2D1Factory vtable
const VTBL_FACTORY_CREATE_HWND_RENDER_TARGET = 14;

// ID2D1HwndRenderTarget vtable
const VTBL_RT_CREATE_SOLID_COLOR_BRUSH = 8;
const VTBL_RT_DRAW_LINE = 15;
const VTBL_RT_CLEAR = 47;
const VTBL_RT_BEGIN_DRAW = 48;
const VTBL_RT_END_DRAW = 49;
const VTBL_RT_RESIZE = 58;

// Wide string helper
function wstr(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

// ANSI string helper
function astr(string $s): FFI\CData
{
    $len = strlen($s) + 1;
    $buf = FFI::new("char[$len]", false);
    for ($i = 0; $i < strlen($s); $i++) {
        $buf[$i] = $s[$i];
    }
    $buf[strlen($s)] = "\0";
    return $buf;
}

// kernel32.dll
$kernel32 = FFI::cdef('
    typedef void* HANDLE;
    typedef HANDLE HINSTANCE;
    typedef HANDLE HMODULE;
    typedef const uint16_t* LPCWSTR;
    typedef const char* LPCSTR;
    typedef void* FARPROC;

    HINSTANCE GetModuleHandleW(LPCWSTR lpModuleName);
    HMODULE LoadLibraryW(LPCWSTR lpLibFileName);
    FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);
    unsigned long GetLastError(void);
    void Sleep(unsigned long dwMilliseconds);
    int FreeLibrary(HMODULE hLibModule);
', 'kernel32.dll');

// user32.dll
$user32 = FFI::cdef('
    typedef void* HANDLE;
    typedef HANDLE HWND;
    typedef HANDLE HDC;
    typedef HANDLE HINSTANCE;
    typedef HANDLE HICON;
    typedef HANDLE HCURSOR;
    typedef HANDLE HBRUSH;
    typedef HANDLE HMENU;
    typedef void*  WNDPROC;

    typedef const uint16_t* LPCWSTR;

    typedef unsigned int   UINT;
    typedef unsigned long  DWORD;
    typedef long           LONG;
    typedef unsigned long long WPARAM;
    typedef long long      LPARAM;
    typedef long long      LRESULT;
    typedef int            BOOL;
    typedef uint16_t       ATOM;

    typedef struct tagPOINT { LONG x; LONG y; } POINT;

    typedef struct tagRECT {
        LONG left;
        LONG top;
        LONG right;
        LONG bottom;
    } RECT;

    typedef struct tagMSG {
        HWND   hwnd;
        UINT   message;
        WPARAM wParam;
        LPARAM lParam;
        DWORD  time;
        POINT  pt;
        DWORD  lPrivate;
    } MSG;

    typedef struct tagWNDCLASSEXW {
        UINT      cbSize;
        UINT      style;
        WNDPROC   lpfnWndProc;
        int       cbClsExtra;
        int       cbWndExtra;
        HINSTANCE hInstance;
        HICON     hIcon;
        HCURSOR   hCursor;
        HBRUSH    hbrBackground;
        LPCWSTR   lpszMenuName;
        LPCWSTR   lpszClassName;
        HICON     hIconSm;
    } WNDCLASSEXW;

    ATOM RegisterClassExW(const WNDCLASSEXW *lpwcx);

    HWND CreateWindowExW(
        DWORD     dwExStyle,
        LPCWSTR   lpClassName,
        LPCWSTR   lpWindowName,
        DWORD     dwStyle,
        int       X,
        int       Y,
        int       nWidth,
        int       nHeight,
        HWND      hWndParent,
        HMENU     hMenu,
        HINSTANCE hInstance,
        void*     lpParam
    );

    BOOL ShowWindow(HWND hWnd, int nCmdShow);
    BOOL UpdateWindow(HWND hWnd);
    BOOL DestroyWindow(HWND hWnd);
    BOOL IsWindow(HWND hWnd);
    BOOL ValidateRect(HWND hWnd, const RECT* lpRect);
    BOOL InvalidateRect(HWND hWnd, const RECT* lpRect, BOOL bErase);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);

    BOOL GetClientRect(HWND hWnd, RECT* lpRect);
', 'user32.dll');

// gdi32.dll
$gdi32 = FFI::cdef('
    typedef void* HGDIOBJ;
    HGDIOBJ GetStockObject(int i);
', 'gdi32.dll');

// Direct2D types
$d2dTypes = FFI::cdef('
    typedef long HRESULT;
    typedef void* HWND;

    typedef struct _GUID {
        uint32_t Data1;
        uint16_t Data2;
        uint16_t Data3;
        uint8_t  Data4[8];
    } GUID;

    typedef struct D2D1_COLOR_F {
        float r, g, b, a;
    } D2D1_COLOR_F;

    typedef struct D2D1_POINT_2F {
        float x, y;
    } D2D1_POINT_2F;

    typedef struct D2D1_SIZE_U {
        uint32_t width, height;
    } D2D1_SIZE_U;

    typedef struct D2D1_PIXEL_FORMAT {
        uint32_t format;
        uint32_t alphaMode;
    } D2D1_PIXEL_FORMAT;

    typedef struct D2D1_MATRIX_3X2_F {
        float _11, _12, _21, _22, _31, _32;
    } D2D1_MATRIX_3X2_F;

    typedef struct D2D1_RENDER_TARGET_PROPERTIES {
        uint32_t type;
        D2D1_PIXEL_FORMAT pixelFormat;
        float dpiX, dpiY;
        uint32_t usage;
        uint32_t minLevel;
    } D2D1_RENDER_TARGET_PROPERTIES;

    typedef struct D2D1_HWND_RENDER_TARGET_PROPERTIES {
        HWND hwnd;
        D2D1_SIZE_U pixelSize;
        uint32_t presentOptions;
    } D2D1_HWND_RENDER_TARGET_PROPERTIES;

    typedef struct D2D1_BRUSH_PROPERTIES {
        float opacity;
        D2D1_MATRIX_3X2_F transform;
    } D2D1_BRUSH_PROPERTIES;

    // COM object (vtable pointer)
    typedef struct IUnknown {
        void** lpVtbl;
    } IUnknown;

    // Function pointer types
    typedef HRESULT (__stdcall *ReleaseFunc)(void* pThis);
    
    // D2D1CreateFactory
    typedef HRESULT (__stdcall *D2D1CreateFactoryFunc)(uint32_t factoryType, const GUID* riid, const void* pFactoryOptions, void** ppIFactory);
    
    // ID2D1Factory::CreateHwndRenderTarget
    typedef HRESULT (__stdcall *CreateHwndRenderTargetFunc)(void* pThis, const D2D1_RENDER_TARGET_PROPERTIES* rtProps, const D2D1_HWND_RENDER_TARGET_PROPERTIES* hwndProps, void** ppRenderTarget);
    
    // ID2D1RenderTarget::CreateSolidColorBrush
    typedef HRESULT (__stdcall *CreateSolidColorBrushFunc)(void* pThis, const D2D1_COLOR_F* color, const D2D1_BRUSH_PROPERTIES* brushProps, void** ppBrush);
    
    // ID2D1RenderTarget::BeginDraw
    typedef void (__stdcall *BeginDrawFunc)(void* pThis);
    
    // ID2D1RenderTarget::EndDraw
    typedef HRESULT (__stdcall *EndDrawFunc)(void* pThis, uint64_t* tag1, uint64_t* tag2);
    
    // ID2D1RenderTarget::Clear
    typedef void (__stdcall *ClearFunc)(void* pThis, const D2D1_COLOR_F* clearColor);
    
    // ID2D1RenderTarget::DrawLine
    typedef void (__stdcall *DrawLineFunc)(void* pThis, D2D1_POINT_2F p0, D2D1_POINT_2F p1, void* brush, float strokeWidth, void* strokeStyle);
    
    // ID2D1HwndRenderTarget::Resize
    typedef HRESULT (__stdcall *ResizeFunc)(void* pThis, const D2D1_SIZE_U* pixelSize);
');

// Get module handle
$hInstance = $kernel32->GetModuleHandleW(null);

// Get DefWindowProcW address
$user32DllName = wstr("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = astr("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

// Prepare class name and window name
$className  = wstr("PHPD2DWindow");
$windowName = wstr("Hello, World! (PHP)");

// Load standard icon and cursor
$hIcon   = $user32->LoadIconW(null, FFI::cast('uint16_t*', IDI_APPLICATION));
$hCursor = $user32->LoadCursorW(null, FFI::cast('uint16_t*', IDC_ARROW));

// Get background brush
$hbrBackground = FFI::cast('void*', COLOR_WINDOW + 1);

// Register window class
$wcex = $user32->new('WNDCLASSEXW');
$wcex->cbSize        = FFI::sizeof($wcex);
$wcex->style         = CS_HREDRAW | CS_VREDRAW;
$wcex->lpfnWndProc   = $defWndProcAddr;
$wcex->cbClsExtra    = 0;
$wcex->cbWndExtra    = 0;
$wcex->hInstance     = $hInstance;
$wcex->hIcon         = $hIcon;
$wcex->hCursor       = $hCursor;
$wcex->hbrBackground = $hbrBackground;
$wcex->lpszMenuName  = null;
$wcex->lpszClassName = FFI::cast('uint16_t*', FFI::addr($className[0]));
$wcex->hIconSm       = $hIcon;

$atom = $user32->RegisterClassExW(FFI::addr($wcex));
if ($atom === 0) {
    $err = $kernel32->GetLastError();
    echo "RegisterClassExW failed (error: $err)\n";
    exit(1);
}

// Create window
$hwnd = $user32->CreateWindowExW(
    0,
    FFI::cast('uint16_t*', FFI::addr($className[0])),
    FFI::cast('uint16_t*', FFI::addr($windowName[0])),
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    640,
    480,
    null,
    null,
    $hInstance,
    null
);

if ($hwnd === null) {
    $err = $kernel32->GetLastError();
    echo "CreateWindowExW failed (error: $err)\n";
    exit(1);
}
echo "Window created\n";

// Load d2d1.dll
$d2d1DllName = wstr("d2d1.dll");
$hD2D1 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d2d1DllName[0])));
if ($hD2D1 === null) {
    echo "Failed to load d2d1.dll\n";
    exit(1);
}
echo "d2d1.dll loaded\n";

// Get D2D1CreateFactory
$d2d1CreateFactoryName = astr("D2D1CreateFactory");
$pfnD2D1CreateFactory = $kernel32->GetProcAddress($hD2D1, FFI::cast('char*', FFI::addr($d2d1CreateFactoryName[0])));
if ($pfnD2D1CreateFactory === null) {
    echo "Failed to get D2D1CreateFactory\n";
    exit(1);
}
$D2D1CreateFactory = FFI::cast($d2dTypes->type('D2D1CreateFactoryFunc'), $pfnD2D1CreateFactory);
echo "D2D1CreateFactory obtained\n";

// IID_ID2D1Factory: {06152247-6F50-465A-9245-118BFD3B6007}
$iidFactory = $d2dTypes->new('GUID');
$iidFactory->Data1 = 0x06152247;
$iidFactory->Data2 = 0x6F50;
$iidFactory->Data3 = 0x465A;
$iidFactory->Data4[0] = 0x92;
$iidFactory->Data4[1] = 0x45;
$iidFactory->Data4[2] = 0x11;
$iidFactory->Data4[3] = 0x8B;
$iidFactory->Data4[4] = 0xFD;
$iidFactory->Data4[5] = 0x3B;
$iidFactory->Data4[6] = 0x60;
$iidFactory->Data4[7] = 0x07;

// Create D2D1 Factory
$ppFactory = FFI::new('void*');
$hr = $D2D1CreateFactory(0, FFI::addr($iidFactory), null, FFI::addr($ppFactory));
if ($hr < 0) {
    echo "D2D1CreateFactory failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
$pFactory = FFI::cast($d2dTypes->type('IUnknown*'), $ppFactory);
echo "ID2D1Factory created\n";

// Setup render target properties
$rtProps = $d2dTypes->new('D2D1_RENDER_TARGET_PROPERTIES');
$rtProps->type = 0;
$rtProps->pixelFormat->format = 0;
$rtProps->pixelFormat->alphaMode = 0;
$rtProps->dpiX = 0.0;
$rtProps->dpiY = 0.0;
$rtProps->usage = 0;
$rtProps->minLevel = 0;

$rect = $user32->new('RECT');
$user32->GetClientRect($hwnd, FFI::addr($rect));
$width = $rect->right - $rect->left;
$height = $rect->bottom - $rect->top;

$hwndProps = $d2dTypes->new('D2D1_HWND_RENDER_TARGET_PROPERTIES');
$hwndProps->hwnd = $hwnd;
$hwndProps->pixelSize->width = $width > 0 ? $width : 640;
$hwndProps->pixelSize->height = $height > 0 ? $height : 480;
$hwndProps->presentOptions = 0;

// Create HwndRenderTarget
$ppRenderTarget = FFI::new('void*');
$pfnCreateHwndRenderTarget = FFI::cast(
    $d2dTypes->type('CreateHwndRenderTargetFunc'),
    $pFactory->lpVtbl[VTBL_FACTORY_CREATE_HWND_RENDER_TARGET]
);
$hr = $pfnCreateHwndRenderTarget($pFactory, FFI::addr($rtProps), FFI::addr($hwndProps), FFI::addr($ppRenderTarget));
if ($hr < 0) {
    echo "CreateHwndRenderTarget failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
$pRenderTarget = FFI::cast($d2dTypes->type('IUnknown*'), $ppRenderTarget);
echo "ID2D1HwndRenderTarget created\n";

// Release factory (no longer needed)
$pfnRelease = FFI::cast($d2dTypes->type('ReleaseFunc'), $pFactory->lpVtbl[VTBL_RELEASE]);
$pfnRelease($pFactory);
echo "Factory released\n";

// Get render target methods
$pfnBeginDraw = FFI::cast($d2dTypes->type('BeginDrawFunc'), $pRenderTarget->lpVtbl[VTBL_RT_BEGIN_DRAW]);
$pfnEndDraw = FFI::cast($d2dTypes->type('EndDrawFunc'), $pRenderTarget->lpVtbl[VTBL_RT_END_DRAW]);
$pfnClear = FFI::cast($d2dTypes->type('ClearFunc'), $pRenderTarget->lpVtbl[VTBL_RT_CLEAR]);
$pfnDrawLine = FFI::cast($d2dTypes->type('DrawLineFunc'), $pRenderTarget->lpVtbl[VTBL_RT_DRAW_LINE]);
$pfnCreateSolidColorBrush = FFI::cast($d2dTypes->type('CreateSolidColorBrushFunc'), $pRenderTarget->lpVtbl[VTBL_RT_CREATE_SOLID_COLOR_BRUSH]);
$pfnResize = FFI::cast($d2dTypes->type('ResizeFunc'), $pRenderTarget->lpVtbl[VTBL_RT_RESIZE]);
$pfnRTRelease = FFI::cast($d2dTypes->type('ReleaseFunc'), $pRenderTarget->lpVtbl[VTBL_RELEASE]);

/**
 * Draw triangle
 */
function drawTriangle($d2dTypes, $pRenderTarget, $pfnBeginDraw, $pfnEndDraw, $pfnClear, $pfnDrawLine, $pfnCreateSolidColorBrush): void
{
    // Colors
    $clearColor = $d2dTypes->new('D2D1_COLOR_F');
    $clearColor->r = 1.0;
    $clearColor->g = 1.0;
    $clearColor->b = 1.0;
    $clearColor->a = 1.0;

    $blueColor = $d2dTypes->new('D2D1_COLOR_F');
    $blueColor->r = 0.0;
    $blueColor->g = 0.0;
    $blueColor->b = 1.0;
    $blueColor->a = 1.0;

    // Triangle points
    $p1 = $d2dTypes->new('D2D1_POINT_2F');
    $p1->x = 320.0;
    $p1->y = 120.0;

    $p2 = $d2dTypes->new('D2D1_POINT_2F');
    $p2->x = 480.0;
    $p2->y = 360.0;

    $p3 = $d2dTypes->new('D2D1_POINT_2F');
    $p3->x = 160.0;
    $p3->y = 360.0;

    // Begin draw
    $pfnBeginDraw($pRenderTarget);

    // Clear
    $pfnClear($pRenderTarget, FFI::addr($clearColor));

    // Create brush
    $ppBrush = FFI::new('void*');
    $hr = $pfnCreateSolidColorBrush($pRenderTarget, FFI::addr($blueColor), null, FFI::addr($ppBrush));
    
    if ($hr >= 0 && FFI::cast('uintptr_t', $ppBrush)->cdata !== 0) {
        $pBrush = FFI::cast($d2dTypes->type('IUnknown*'), $ppBrush);
        
        // Draw triangle lines
        $pfnDrawLine($pRenderTarget, $p1, $p2, $pBrush, 1.0, null);
        $pfnDrawLine($pRenderTarget, $p2, $p3, $pBrush, 1.0, null);
        $pfnDrawLine($pRenderTarget, $p3, $p1, $pBrush, 1.0, null);
        
        // Release brush
        $pfnBrushRelease = FFI::cast($d2dTypes->type('ReleaseFunc'), $pBrush->lpVtbl[VTBL_RELEASE]);
        $pfnBrushRelease($pBrush);
    }

    // End draw
    $hr = $pfnEndDraw($pRenderTarget, null, null);
    if ($hr < 0) {
        echo "EndDraw failed: " . sprintf("0x%08X", $hr) . "\n";
    }
}

// Show window
$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

echo "Starting message loop\n";

// Message loop
$msg = $user32->new('MSG');
$lastMessage = 0;

while (true) {
    if ($user32->IsWindow($hwnd) == 0) {
        break;
    }

    while ($user32->PeekMessageW(FFI::addr($msg), null, 0, 0, PM_REMOVE) != 0) {
        if ((int)$msg->message === WM_QUIT) {
            break 2;
        }
        
        // Handle WM_PAINT
        if ((int)$msg->message === WM_PAINT) {
            drawTriangle($d2dTypes, $pRenderTarget, $pfnBeginDraw, $pfnEndDraw, $pfnClear, $pfnDrawLine, $pfnCreateSolidColorBrush);
            $user32->ValidateRect($hwnd, null);
        }
        
        // Handle WM_SIZE
        if ((int)$msg->message === WM_SIZE) {
            $width = (int)$msg->lParam & 0xFFFF;
            $height = ((int)$msg->lParam >> 16) & 0xFFFF;
            $size = $d2dTypes->new('D2D1_SIZE_U');
            $size->width = $width;
            $size->height = $height;
            $pfnResize($pRenderTarget, FFI::addr($size));
        }
        
        $user32->TranslateMessage(FFI::addr($msg));
        $user32->DispatchMessageW(FFI::addr($msg));
    }

    // Redraw periodically
    static $lastRedraw = 0;
    $now = microtime(true);
    if ($now - $lastRedraw > 0.016) {  // ~60 FPS
        drawTriangle($d2dTypes, $pRenderTarget, $pfnBeginDraw, $pfnEndDraw, $pfnClear, $pfnDrawLine, $pfnCreateSolidColorBrush);
        $lastRedraw = $now;
    }

    $kernel32->Sleep(1);
}

// Cleanup
echo "Releasing render target...\n";
$pfnRTRelease($pRenderTarget);

echo "Freeing d2d1.dll...\n";
$kernel32->FreeLibrary($hD2D1);

echo "Program ended normally\n";
