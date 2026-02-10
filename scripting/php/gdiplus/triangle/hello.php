<?php
declare(strict_types=1);

/*
  Win32 GUI from PHP via FFI - GDI+ Path Gradient Triangle Demo
  
  Draws a path gradient-filled triangle (red, green, blue corners, gray center)
  using GDI+ Path Gradient Brush with double buffering to prevent flickering.
*/

// Window styles
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

// Window messages
const WM_QUIT           = 0x0012;
const WM_PAINT          = 0x000F;
const WM_ERASEBKGND     = 0x0014;
const PM_REMOVE         = 0x0001;

// System resources
const IDI_APPLICATION   = 32512;
const IDC_ARROW         = 32512;
const BLACK_BRUSH       = 4;
const WHITE_BRUSH       = 0;

// BitBlt raster operation
const SRCCOPY           = 0x00CC0020;

/**
 * Convert UTF-8 string to UTF-16LE (wide string) buffer
 */
function wbuf(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

/**
 * Convert string to ANSI char buffer
 */
function abuf(string $s): FFI\CData
{
    $len = strlen($s) + 1;
    $buf = FFI::new("char[$len]", false);
    FFI::memcpy($buf, $s . "\0", $len);
    return $buf;
}

// Load kernel32.dll
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

// Load user32.dll
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

    typedef struct tagPAINTSTRUCT {
        HDC  hdc;
        BOOL fErase;
        RECT rcPaint;
        BOOL fRestore;
        BOOL fIncUpdate;
        uint8_t rgbReserved[32];
    } PAINTSTRUCT;

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

    HDC  GetDC(HWND hWnd);
    int  ReleaseDC(HWND hWnd, HDC hDC);

    BOOL IsWindow(HWND hWnd);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);

    BOOL GetClientRect(HWND hWnd, RECT *lpRect);
    BOOL InvalidateRect(HWND hWnd, const RECT *lpRect, BOOL bErase);

    HDC  BeginPaint(HWND hWnd, PAINTSTRUCT *lpPaint);
    BOOL EndPaint(HWND hWnd, const PAINTSTRUCT *lpPaint);

    int FillRect(HDC hDC, const RECT *lprc, HBRUSH hbr);
', 'user32.dll');

// Load gdi32.dll with double buffering functions
$gdi32 = FFI::cdef('
    typedef void* HDC;
    typedef void* HGDIOBJ;
    typedef void* HBITMAP;
    typedef int BOOL;
    typedef unsigned long COLORREF;

    HGDIOBJ GetStockObject(int i);
    HDC CreateCompatibleDC(HDC hdc);
    HBITMAP CreateCompatibleBitmap(HDC hdc, int cx, int cy);
    HGDIOBJ SelectObject(HDC hdc, HGDIOBJ h);
    BOOL DeleteObject(HGDIOBJ ho);
    BOOL DeleteDC(HDC hdc);
    BOOL BitBlt(HDC hdc, int x, int y, int cx, int cy, HDC hdcSrc, int x1, int y1, unsigned long rop);
', 'gdi32.dll');

// Load gdiplus.dll
$gdiplus = FFI::cdef('
    typedef void* HDC;
    typedef void* GpGraphics;
    typedef void* GpPath;
    typedef void* GpBrush;
    typedef int INT;

    typedef struct {
        INT x;
        INT y;
    } GpPoint;

    typedef struct {
        unsigned int GdiplusVersion;
        void* DebugEventCallback;
        int SuppressBackgroundThread;
        int SuppressExternalCodecs;
    } GdiplusStartupInput;

    int GdiplusStartup(unsigned long long* token, GdiplusStartupInput *input, void *output);
    void GdiplusShutdown(unsigned long long token);
    
    int GdipCreateFromHDC(HDC hdc, GpGraphics* graphics);
    int GdipDeleteGraphics(GpGraphics graphics);
    
    int GdipCreatePath(int brushMode, GpPath* path);
    int GdipDeletePath(GpPath path);
    int GdipAddPathLine2I(GpPath path, const GpPoint* points, int count);
    int GdipClosePathFigure(GpPath path);
    
    int GdipCreatePathGradientFromPath(GpPath path, GpBrush* polyGradient);
    int GdipSetPathGradientCenterColor(GpBrush brush, unsigned int argb);
    int GdipSetPathGradientSurroundColorsWithCount(GpBrush brush, unsigned int* argb_colors, int* count);
    int GdipDeleteBrush(GpBrush brush);
    
    int GdipFillPath(GpGraphics graphics, GpBrush brush, GpPath path);
', 'gdiplus.dll');

// Get module handle
$hInstance = $kernel32->GetModuleHandleW(null);

// Get DefWindowProcW address for window procedure
$user32DllName = wbuf("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = abuf("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

// Prepare class name and window name
$className  = wbuf("PHPGDIPlusTriangleWindow");
$windowName = wbuf("Hello, World! (PHP GDI+)");

// Load standard icon and cursor
$hIcon   = $user32->LoadIconW(null, FFI::cast('uint16_t*', IDI_APPLICATION));
$hCursor = $user32->LoadCursorW(null, FFI::cast('uint16_t*', IDC_ARROW));

// Get white brush for background
$hbrBackground = $gdi32->GetStockObject(WHITE_BRUSH);

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

// Initialize GDI+
$startupInput = $gdiplus->new('GdiplusStartupInput');
$startupInput->GdiplusVersion = 1;
$startupInput->DebugEventCallback = null;
$startupInput->SuppressBackgroundThread = 0;
$startupInput->SuppressExternalCodecs = 0;

$token = $gdiplus->new('unsigned long long');
$status = $gdiplus->GdiplusStartup(FFI::addr($token), FFI::addr($startupInput), null);
if ($status != 0) {
    echo "GdiplusStartup failed (status: $status)\n";
    exit(1);
}
$gdipToken = $token->cdata;

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
 * Draw path gradient triangle using GDI+ with double buffering
 * 
 * Double buffering eliminates flickering by:
 * 1. Creating an off-screen bitmap
 * 2. Drawing everything to the off-screen bitmap
 * 3. Copying the completed image to the screen in one operation
 */
function drawTriangleGDIPlus($gdiplus, $user32, $gdi32, $hdc, $hwnd): void
{
    // Get client area dimensions
    $rect = $user32->new('RECT');
    $user32->GetClientRect($hwnd, FFI::addr($rect));
    $width  = $rect->right - $rect->left;
    $height = $rect->bottom - $rect->top;

    // Skip if window is minimized or has no size
    if ($width <= 0 || $height <= 0) {
        return;
    }

    // === Double Buffering Setup ===
    // Create memory DC compatible with screen DC
    $memDC = $gdi32->CreateCompatibleDC($hdc);
    if ($memDC === null) {
        return;
    }

    // Create bitmap for off-screen rendering
    $memBitmap = $gdi32->CreateCompatibleBitmap($hdc, $width, $height);
    if ($memBitmap === null) {
        $gdi32->DeleteDC($memDC);
        return;
    }

    // Select bitmap into memory DC (save old bitmap for cleanup)
    $oldBitmap = $gdi32->SelectObject($memDC, $memBitmap);

    // === Drawing to Off-Screen Buffer ===
    // Clear background with white
    $whiteBrush = $gdi32->GetStockObject(WHITE_BRUSH);
    $user32->FillRect($memDC, FFI::addr($rect), $whiteBrush);

    // Create GDI+ graphics from memory DC (not screen DC)
    $graphics = $gdiplus->new('GpGraphics*');
    $status = $gdiplus->GdipCreateFromHDC($memDC, FFI::addr($graphics));
    if ($status != 0) {
        // Cleanup on error
        $gdi32->SelectObject($memDC, $oldBitmap);
        $gdi32->DeleteObject($memBitmap);
        $gdi32->DeleteDC($memDC);
        return;
    }

    // Create graphics path for the triangle
    $path = $gdiplus->new('GpPath*');
    $gdiplus->GdipCreatePath(0, FFI::addr($path));

    // Define triangle vertices
    $points = $gdiplus->new('GpPoint[3]');
    
    // Top vertex (center-top)
    $points[0]->x = (int)($width / 2);
    $points[0]->y = (int)($height / 4);
    
    // Bottom-right vertex
    $points[1]->x = (int)($width * 3 / 4);
    $points[1]->y = (int)($height * 3 / 4);
    
    // Bottom-left vertex
    $points[2]->x = (int)($width / 4);
    $points[2]->y = (int)($height * 3 / 4);

    // Add triangle to path and close it
    $gdiplus->GdipAddPathLine2I($path, $points, 3);
    $gdiplus->GdipClosePathFigure($path);

    // Create path gradient brush from the triangle path
    $brush = $gdiplus->new('GpBrush*');
    $gdiplus->GdipCreatePathGradientFromPath($path, FFI::addr($brush));

    // Set center color (gray)
    $gdiplus->GdipSetPathGradientCenterColor($brush, 0xff555555);

    // Set surrounding colors for each vertex
    $colors = $gdiplus->new('unsigned int[3]');
    $colors[0] = 0xffff0000;  // Red (top vertex)
    $colors[1] = 0xff00ff00;  // Green (bottom-right vertex)
    $colors[2] = 0xff0000ff;  // Blue (bottom-left vertex)

    $count = $gdiplus->new('int');
    $count->cdata = 3;
    $gdiplus->GdipSetPathGradientSurroundColorsWithCount($brush, $colors, FFI::addr($count));

    // Fill the triangle with gradient
    $gdiplus->GdipFillPath($graphics, $brush, $path);

    // Cleanup GDI+ resources
    $gdiplus->GdipDeleteBrush($brush);
    $gdiplus->GdipDeletePath($path);
    $gdiplus->GdipDeleteGraphics($graphics);

    // === Transfer to Screen ===
    // Copy off-screen buffer to screen in one operation (no flicker)
    $gdi32->BitBlt($hdc, 0, 0, $width, $height, $memDC, 0, 0, SRCCOPY);

    // Cleanup GDI resources
    $gdi32->SelectObject($memDC, $oldBitmap);
    $gdi32->DeleteObject($memBitmap);
    $gdi32->DeleteDC($memDC);
}

// Track last draw time for frame rate control
$lastDraw = 0;

// Message pump with direct GDI+ rendering
$msg = $user32->new('MSG');

while (true) {
    // Exit if window is closed
    if ($user32->IsWindow($hwnd) == 0) {
        break;
    }

    // Process Windows messages
    if ($user32->PeekMessageW(FFI::addr($msg), null, 0, 0, PM_REMOVE) != 0) {
        if ((int)$msg->message === WM_QUIT) {
            break;
        }
        $user32->TranslateMessage(FFI::addr($msg));
        $user32->DispatchMessageW(FFI::addr($msg));
    } else {
        // Draw at approximately 60 FPS when idle
        $now = microtime(true);
        if ($now - $lastDraw > 0.016) {
            $hdc = $user32->GetDC($hwnd);
            if ($hdc) {
                drawTriangleGDIPlus($gdiplus, $user32, $gdi32, $hdc, $hwnd);
                $user32->ReleaseDC($hwnd, $hdc);
            }
            $lastDraw = $now;
        }
        // Small sleep to reduce CPU usage
        $kernel32->Sleep(1);
    }
}

// Cleanup GDI+
$gdiplus->GdiplusShutdown($gdipToken);

echo "Program ended normally\n";
