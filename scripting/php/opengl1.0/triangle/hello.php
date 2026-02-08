<?php
declare(strict_types=1);

/*
  Win32 + OpenGL 1.0 from PHP via FFI
  
  Draws a colored triangle using legacy OpenGL (glBegin/glEnd).
*/

// Window styles
const WS_OVERLAPPED       = 0x00000000;
const WS_CAPTION          = 0x00C00000;
const WS_SYSMENU          = 0x00080000;
const WS_THICKFRAME       = 0x00040000;
const WS_MINIMIZEBOX      = 0x00020000;
const WS_MAXIMIZEBOX      = 0x00010000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

const CS_OWNDC            = 0x0020;
const CW_USEDEFAULT       = 0x80000000;
const SW_SHOWDEFAULT      = 10;

const WM_QUIT             = 0x0012;
const PM_REMOVE           = 0x0001;

const IDI_APPLICATION     = 32512;
const IDC_ARROW           = 32512;
const BLACK_BRUSH         = 4;

// Pixel format flags
const PFD_DRAW_TO_WINDOW  = 0x00000004;
const PFD_SUPPORT_OPENGL  = 0x00000020;
const PFD_DOUBLEBUFFER    = 0x00000001;
const PFD_TYPE_RGBA       = 0;
const PFD_MAIN_PLANE      = 0;

// OpenGL constants
const GL_COLOR_BUFFER_BIT = 0x00004000;
const GL_TRIANGLES        = 0x0004;

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

    HDC  GetDC(HWND hWnd);
    int  ReleaseDC(HWND hWnd, HDC hDC);

    BOOL IsWindow(HWND hWnd);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);
', 'user32.dll');

// gdi32.dll
$gdi32 = FFI::cdef('
    typedef void* HDC;
    typedef void* HGDIOBJ;
    typedef int BOOL;
    typedef unsigned short WORD;
    typedef unsigned long DWORD;
    typedef unsigned char BYTE;

    typedef struct tagPIXELFORMATDESCRIPTOR {
        WORD  nSize;
        WORD  nVersion;
        DWORD dwFlags;
        BYTE  iPixelType;
        BYTE  cColorBits;
        BYTE  cRedBits;
        BYTE  cRedShift;
        BYTE  cGreenBits;
        BYTE  cGreenShift;
        BYTE  cBlueBits;
        BYTE  cBlueShift;
        BYTE  cAlphaBits;
        BYTE  cAlphaShift;
        BYTE  cAccumBits;
        BYTE  cAccumRedBits;
        BYTE  cAccumGreenBits;
        BYTE  cAccumBlueBits;
        BYTE  cAccumAlphaBits;
        BYTE  cDepthBits;
        BYTE  cStencilBits;
        BYTE  cAuxBuffers;
        BYTE  iLayerType;
        BYTE  bReserved;
        DWORD dwLayerMask;
        DWORD dwVisibleMask;
        DWORD dwDamageMask;
    } PIXELFORMATDESCRIPTOR;

    HGDIOBJ GetStockObject(int i);
    int ChoosePixelFormat(HDC hdc, const PIXELFORMATDESCRIPTOR *ppfd);
    BOOL SetPixelFormat(HDC hdc, int format, const PIXELFORMATDESCRIPTOR *ppfd);
    BOOL SwapBuffers(HDC hdc);
', 'gdi32.dll');

// opengl32.dll
$opengl32 = FFI::cdef('
    typedef void* HDC;
    typedef void* HGLRC;
    typedef int BOOL;
    typedef unsigned int GLenum;
    typedef unsigned int GLbitfield;
    typedef float GLfloat;
    typedef int GLint;

    HGLRC wglCreateContext(HDC hdc);
    BOOL wglMakeCurrent(HDC hdc, HGLRC hglrc);
    BOOL wglDeleteContext(HGLRC hglrc);

    void glClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    void glClear(GLbitfield mask);
    void glBegin(GLenum mode);
    void glEnd(void);
    void glColor3f(GLfloat red, GLfloat green, GLfloat blue);
    void glVertex2f(GLfloat x, GLfloat y);
', 'opengl32.dll');

// Get module handle
$hInstance = $kernel32->GetModuleHandleW(null);

// Get DefWindowProcW address
$user32DllName = wbuf("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = abuf("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

// Prepare class name and window name
$className  = wbuf("PHPOpenGLWindow");
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

// Get DC
$hDC = $user32->GetDC($hwnd);

/**
 * Enable OpenGL
 */
function enableOpenGL($gdi32, $opengl32, $hDC)
{
    // Setup pixel format
    $pfd = $gdi32->new('PIXELFORMATDESCRIPTOR');
    FFI::memset(FFI::addr($pfd), 0, FFI::sizeof($pfd));
    
    $pfd->nSize      = FFI::sizeof($pfd);
    $pfd->nVersion   = 1;
    $pfd->dwFlags    = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    $pfd->iPixelType = PFD_TYPE_RGBA;
    $pfd->cColorBits = 24;
    $pfd->cDepthBits = 16;
    $pfd->iLayerType = PFD_MAIN_PLANE;

    $iFormat = $gdi32->ChoosePixelFormat($hDC, FFI::addr($pfd));
    if ($iFormat === 0) {
        echo "ChoosePixelFormat failed\n";
        return null;
    }

    if (!$gdi32->SetPixelFormat($hDC, $iFormat, FFI::addr($pfd))) {
        echo "SetPixelFormat failed\n";
        return null;
    }

    $hRC = $opengl32->wglCreateContext($hDC);
    if ($hRC === null) {
        echo "wglCreateContext failed\n";
        return null;
    }

    $opengl32->wglMakeCurrent($hDC, $hRC);

    return $hRC;
}

/**
 * Disable OpenGL
 */
function disableOpenGL($opengl32, $user32, $hwnd, $hDC, $hRC): void
{
    $opengl32->wglMakeCurrent(null, null);
    $opengl32->wglDeleteContext($hRC);
    $user32->ReleaseDC($hwnd, $hDC);
}

/**
 * Draw triangle
 */
function drawTriangle($opengl32): void
{
    $opengl32->glBegin(GL_TRIANGLES);

    // Top vertex - Red
    $opengl32->glColor3f(1.0, 0.0, 0.0);
    $opengl32->glVertex2f(0.0, 0.5);

    // Bottom-right vertex - Green
    $opengl32->glColor3f(0.0, 1.0, 0.0);
    $opengl32->glVertex2f(0.5, -0.5);

    // Bottom-left vertex - Blue
    $opengl32->glColor3f(0.0, 0.0, 1.0);
    $opengl32->glVertex2f(-0.5, -0.5);

    $opengl32->glEnd();
}

// Enable OpenGL
$hRC = enableOpenGL($gdi32, $opengl32, $hDC);
if ($hRC === null) {
    echo "Failed to enable OpenGL\n";
    exit(1);
}

echo "OpenGL initialized successfully\n";

// Message loop
$msg = $user32->new('MSG');
$bQuit = false;

while (!$bQuit) {
    if ($user32->IsWindow($hwnd) == 0) {
        break;
    }

    if ($user32->PeekMessageW(FFI::addr($msg), null, 0, 0, PM_REMOVE) != 0) {
        if ((int)$msg->message === WM_QUIT) {
            $bQuit = true;
        } else {
            $user32->TranslateMessage(FFI::addr($msg));
            $user32->DispatchMessageW(FFI::addr($msg));
        }
    } else {
        // Render
        $opengl32->glClearColor(0.0, 0.0, 0.0, 0.0);
        $opengl32->glClear(GL_COLOR_BUFFER_BIT);

        drawTriangle($opengl32);

        $gdi32->SwapBuffers($hDC);

        $kernel32->Sleep(1);
    }
}

// Cleanup
disableOpenGL($opengl32, $user32, $hwnd, $hDC, $hRC);
$user32->DestroyWindow($hwnd);

echo "Program ended normally\n";
