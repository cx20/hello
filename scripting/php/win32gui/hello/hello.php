<?php
declare(strict_types=1);

/*
  Win32 GUI from PHP via FFI - Using RegisterClassEx with DefWindowProc.
  
  This creates a proper window class like the C version, using DefWindowProc
  as the window procedure for standard window behavior.
*/

const WS_OVERLAPPED     = 0x00000000;
const WS_CAPTION        = 0x00C00000;
const WS_SYSMENU        = 0x00080000;
const WS_THICKFRAME     = 0x00040000;
const WS_MINIMIZEBOX    = 0x00020000;
const WS_MAXIMIZEBOX    = 0x00010000;
const WS_VISIBLE        = 0x10000000;

const WS_OVERLAPPEDWINDOW =
    WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

const CS_HREDRAW        = 0x0002;
const CS_VREDRAW        = 0x0001;

const CW_USEDEFAULT     = 0x80000000;
const SW_SHOW           = 5;
const SW_SHOWDEFAULT    = 10;

const WM_QUIT           = 0x0012;
const WM_PAINT          = 0x000F;
const WM_DESTROY        = 0x0002;
const PM_REMOVE         = 0x0001;

const COLOR_WINDOW      = 5;

const IDI_APPLICATION   = 32512;
const IDC_ARROW         = 32512;

function wbuf(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

// ANSI string buffer for GetProcAddress
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

    HDC  BeginPaint(HWND hWnd, PAINTSTRUCT *lpPaint);
    BOOL EndPaint(HWND hWnd, const PAINTSTRUCT *lpPaint);

    BOOL IsWindow(HWND hWnd);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    LRESULT DefWindowProcW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);
', 'user32.dll');

$gdi32 = FFI::cdef('
    typedef void* HDC;
    typedef void* HGDIOBJ;
    typedef const uint16_t* LPCWSTR;
    typedef int BOOL;
    typedef unsigned long COLORREF;

    BOOL TextOutW(HDC hdc, int x, int y, LPCWSTR lpString, int c);
    COLORREF SetBkColor(HDC hdc, COLORREF color);
    int GetStockObject(int i);
    HGDIOBJ SelectObject(HDC hdc, HGDIOBJ h);
', 'gdi32.dll');

// Get module handle
$hInstance = $kernel32->GetModuleHandleW(null);

// Get DefWindowProcW address via GetProcAddress
$user32DllName = wbuf("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
if ($hUser32 === null) {
    echo "LoadLibraryW(user32.dll) failed\n";
    exit(1);
}

$procName = abuf("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));
if ($defWndProcAddr === null) {
    echo "GetProcAddress(DefWindowProcW) failed\n";
    exit(1);
}

echo "DefWindowProcW address obtained\n";

// Prepare class name and window name
$className  = wbuf("PHPWindowClass");
$windowName = wbuf("Hello, World! (PHP)");

// Load standard icon and cursor using MAKEINTRESOURCE equivalent
$hIcon   = $user32->LoadIconW(null, FFI::cast('uint16_t*', IDI_APPLICATION));
$hCursor = $user32->LoadCursorW(null, FFI::cast('uint16_t*', IDC_ARROW));

// Create brush for window background (COLOR_WINDOW + 1)
$hbrBackground = FFI::cast('void*', COLOR_WINDOW + 1);

// Register window class
$wcex = $user32->new('WNDCLASSEXW');
$wcex->cbSize        = FFI::sizeof($wcex);
$wcex->style         = CS_HREDRAW | CS_VREDRAW;
$wcex->lpfnWndProc   = $defWndProcAddr;  // Use DefWindowProcW address
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

echo "Window class registered successfully (ATOM: $atom)\n";

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

echo "Window created successfully\n";

$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

// Draw text (one-shot, since we can't handle WM_PAINT with DefWindowProc alone)
$hdc = $user32->GetDC($hwnd);
if ($hdc !== null) {
    $text = wbuf("Hello, Win32 GUI World! (PHP FFI with RegisterClassEx)");
    $len  = intdiv(FFI::sizeof($text), 2) - 1;
    $gdi32->TextOutW($hdc, 10, 10, FFI::cast('uint16_t*', FFI::addr($text[0])), $len);
    $user32->ReleaseDC($hwnd, $hdc);
}

// Non-blocking message pump
$msg = $user32->new('MSG');

while (true) {
    if ($user32->IsWindow($hwnd) == 0) {
        echo "Window closed\n";
        break;
    }

    while ($user32->PeekMessageW(FFI::addr($msg), null, 0, 0, PM_REMOVE) != 0) {
        if ((int)$msg->message === WM_QUIT) {
            echo "WM_QUIT received\n";
            break 2;
        }
        $user32->TranslateMessage(FFI::addr($msg));
        $user32->DispatchMessageW(FFI::addr($msg));
    }

    $kernel32->Sleep(10);
}

echo "Program ended normally\n";