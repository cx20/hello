<?php
declare(strict_types=1);

/*
  Win32 GUI from PHP via FFI - GradientFill Triangle Demo
  
  Draws a gradient-filled triangle using GDI's GradientFill function,
  similar to the C version using TRIVERTEX and GRADIENT_TRIANGLE.
*/

const WS_OVERLAPPED     = 0x00000000;
const WS_CAPTION        = 0x00C00000;
const WS_SYSMENU        = 0x00080000;
const WS_THICKFRAME     = 0x00040000;
const WS_MINIMIZEBOX    = 0x00020000;
const WS_MAXIMIZEBOX    = 0x00010000;

const WS_OVERLAPPEDWINDOW =
    WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

const CS_OWNDC          = 0x0020;

const CW_USEDEFAULT     = 0x80000000;
const SW_SHOWDEFAULT    = 10;

const WM_QUIT           = 0x0012;
const PM_REMOVE         = 0x0001;

const IDI_APPLICATION   = 32512;
const IDC_ARROW         = 32512;
const BLACK_BRUSH       = 4;

const GRADIENT_FILL_TRIANGLE = 0x00000002;

function wbuf(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

function abuf(string $s): FFI\CData
{
    $len = strlen($s) + 1;
    $buf = FFI::new("char[$len]", false);
    FFI::memcpy($buf, $s . "\0", $len);
    return $buf;
}

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
', 'kernel32.dll');

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

    typedef struct tagRECT {
        LONG left;
        LONG top;
        LONG right;
        LONG bottom;
    } RECT;

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
    BOOL InvalidateRect(HWND hWnd, const RECT *lpRect, BOOL bErase);

    HDC  GetDC(HWND hWnd);
    int  ReleaseDC(HWND hWnd, HDC hDC);

    BOOL IsWindow(HWND hWnd);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);

    BOOL GetClientRect(HWND hWnd, RECT *lpRect);

    int FillRect(HDC hDC, const RECT *lprc, HBRUSH hbr);
', 'user32.dll');

$gdi32 = FFI::cdef('
    typedef void* HDC;
    typedef void* HGDIOBJ;
    typedef int BOOL;
    typedef unsigned long COLORREF;

    HGDIOBJ GetStockObject(int i);
', 'gdi32.dll');

// msimg32.dll for GradientFill
$msimg32 = FFI::cdef('
    typedef void* HDC;
    typedef int BOOL;
    typedef unsigned long ULONG;

    typedef struct _TRIVERTEX {
        long        x;
        long        y;
        uint16_t    Red;
        uint16_t    Green;
        uint16_t    Blue;
        uint16_t    Alpha;
    } TRIVERTEX;

    typedef struct _GRADIENT_TRIANGLE {
        unsigned long Vertex1;
        unsigned long Vertex2;
        unsigned long Vertex3;
    } GRADIENT_TRIANGLE;

    BOOL GradientFill(
        HDC        hdc,
        TRIVERTEX *pVertex,
        ULONG      nVertex,
        void      *pMesh,
        ULONG      nMesh,
        ULONG      ulMode
    );
', 'msimg32.dll');

// Get module handle
$hInstance = $kernel32->GetModuleHandleW(null);

// Get DefWindowProcW address
$user32DllName = wbuf("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = abuf("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

// Prepare class name and window name
$className  = wbuf("PHPTriangleWindow");
$windowName = wbuf("Hello, World! (PHP)");

// Load standard icon and cursor
$hIcon   = $user32->LoadIconW(null, FFI::cast('uint16_t*', IDI_APPLICATION));
$hCursor = $user32->LoadCursorW(null, FFI::cast('uint16_t*', IDC_ARROW));

// Get black brush for background
$hbrBackground = $gdi32->GetStockObject(BLACK_BRUSH);

// Register window class
$wcex = $user32->new('WNDCLASSEXW');
$wcex->cbSize        = FFI::sizeof($wcex);
$wcex->style         = CS_OWNDC;
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

$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

/**
 * Draw gradient triangle using GDI GradientFill
 */
function drawTriangle($msimg32, $gdi32, $user32, $hdc, $hwnd): void
{
    // Get client area size
    $rect = $user32->new('RECT');
    $user32->GetClientRect($hwnd, FFI::addr($rect));
    $width  = $rect->right - $rect->left;
    $height = $rect->bottom - $rect->top;

    // Fill background with black
    $blackBrush = $gdi32->GetStockObject(BLACK_BRUSH);
    $user32->FillRect($hdc, FFI::addr($rect), $blackBrush);

    // Create TRIVERTEX array (3 vertices)
    $vertices = $msimg32->new('TRIVERTEX[3]');

    // Top vertex - Red
    $vertices[0]->x     = (int)($width * 1 / 2);
    $vertices[0]->y     = (int)($height * 1 / 4);
    $vertices[0]->Red   = 0xffff;
    $vertices[0]->Green = 0x0000;
    $vertices[0]->Blue  = 0x0000;
    $vertices[0]->Alpha = 0x0000;

    // Bottom-right vertex - Green
    $vertices[1]->x     = (int)($width * 3 / 4);
    $vertices[1]->y     = (int)($height * 3 / 4);
    $vertices[1]->Red   = 0x0000;
    $vertices[1]->Green = 0xffff;
    $vertices[1]->Blue  = 0x0000;
    $vertices[1]->Alpha = 0x0000;

    // Bottom-left vertex - Blue
    $vertices[2]->x     = (int)($width * 1 / 4);
    $vertices[2]->y     = (int)($height * 3 / 4);
    $vertices[2]->Red   = 0x0000;
    $vertices[2]->Green = 0x0000;
    $vertices[2]->Blue  = 0xffff;
    $vertices[2]->Alpha = 0x0000;

    // Create GRADIENT_TRIANGLE
    $triangle = $msimg32->new('GRADIENT_TRIANGLE');
    $triangle->Vertex1 = 0;
    $triangle->Vertex2 = 1;
    $triangle->Vertex3 = 2;

    // Draw the gradient triangle
    $msimg32->GradientFill(
        $hdc,
        FFI::addr($vertices[0]),
        3,
        FFI::addr($triangle),
        1,
        GRADIENT_FILL_TRIANGLE
    );
}

// Initial draw
$hdc = $user32->GetDC($hwnd);
if ($hdc !== null) {
    drawTriangle($msimg32, $gdi32, $user32, $hdc, $hwnd);
    $user32->ReleaseDC($hwnd, $hdc);
}

// Message pump with periodic redraw
$msg = $user32->new('MSG');
$lastDraw = time();

while (true) {
    if ($user32->IsWindow($hwnd) == 0) {
        break;
    }

    while ($user32->PeekMessageW(FFI::addr($msg), null, 0, 0, PM_REMOVE) != 0) {
        if ((int)$msg->message === WM_QUIT) {
            break 2;
        }
        $user32->TranslateMessage(FFI::addr($msg));
        $user32->DispatchMessageW(FFI::addr($msg));
    }

    // Redraw periodically (every 100ms) to handle window resize/repaint
    $now = microtime(true);
    static $lastRedraw = 0;
    if ($now - $lastRedraw > 0.1) {
        $hdc = $user32->GetDC($hwnd);
        if ($hdc !== null) {
            drawTriangle($msimg32, $gdi32, $user32, $hdc, $hwnd);
            $user32->ReleaseDC($hwnd, $hdc);
        }
        $lastRedraw = $now;
    }

    $kernel32->Sleep(10);
}

echo "Program ended normally\n";