<?php
declare(strict_types=1);

/*
  Win32 + OpenGL 2.0 from PHP via FFI
  
  Draws a colored triangle using OpenGL 2.0 with:
  - Vertex Buffer Objects (VBO)
  - GLSL Shaders (Vertex & Fragment)
  - wglGetProcAddress for extension functions
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
const GL_FLOAT            = 0x1406;
const GL_FALSE            = 0;
const GL_TRUE             = 1;

// OpenGL 2.0 constants
const GL_ARRAY_BUFFER     = 0x8892;
const GL_STATIC_DRAW      = 0x88E4;
const GL_FRAGMENT_SHADER  = 0x8B30;
const GL_VERTEX_SHADER    = 0x8B31;
const GL_COMPILE_STATUS   = 0x8B81;
const GL_LINK_STATUS      = 0x8B82;
const GL_INFO_LOG_LENGTH  = 0x8B84;

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

// opengl32.dll - Base OpenGL + wglGetProcAddress
$opengl32 = FFI::cdef('
    typedef void* HDC;
    typedef void* HGLRC;
    typedef void* PROC;
    typedef int BOOL;
    typedef unsigned int GLenum;
    typedef unsigned int GLbitfield;
    typedef float GLfloat;
    typedef int GLint;
    typedef int GLsizei;
    typedef unsigned int GLuint;

    HGLRC wglCreateContext(HDC hdc);
    BOOL wglMakeCurrent(HDC hdc, HGLRC hglrc);
    BOOL wglDeleteContext(HGLRC hglrc);
    PROC wglGetProcAddress(const char *name);

    void glClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    void glClear(GLbitfield mask);
    void glDrawArrays(GLenum mode, GLint first, GLsizei count);
', 'opengl32.dll');

// FFI for OpenGL 2.0 function pointer types
$glext = FFI::cdef('
    typedef unsigned int GLenum;
    typedef int GLint;
    typedef int GLsizei;
    typedef unsigned int GLuint;
    typedef char GLchar;
    typedef unsigned char GLboolean;
    typedef float GLfloat;
    typedef int64_t GLsizeiptr;

    // Function pointer types for OpenGL 2.0
    typedef void (*PFNGLGENBUFFERSPROC)(GLsizei n, GLuint *buffers);
    typedef void (*PFNGLBINDBUFFERPROC)(GLenum target, GLuint buffer);
    typedef void (*PFNGLBUFFERDATAPROC)(GLenum target, GLsizeiptr size, const void *data, GLenum usage);
    typedef GLuint (*PFNGLCREATESHADERPROC)(GLenum type);
    typedef void (*PFNGLSHADERSOURCEPROC)(GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
    typedef void (*PFNGLCOMPILESHADERPROC)(GLuint shader);
    typedef void (*PFNGLGETSHADERIVPROC)(GLuint shader, GLenum pname, GLint *params);
    typedef void (*PFNGLGETSHADERINFOLOGPROC)(GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
    typedef GLuint (*PFNGLCREATEPROGRAMPROC)(void);
    typedef void (*PFNGLATTACHSHADERPROC)(GLuint program, GLuint shader);
    typedef void (*PFNGLLINKPROGRAMPROC)(GLuint program);
    typedef void (*PFNGLGETPROGRAMIVPROC)(GLuint program, GLenum pname, GLint *params);
    typedef void (*PFNGLGETPROGRAMINFOLOGPROC)(GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog);
    typedef void (*PFNGLUSEPROGRAMPROC)(GLuint program);
    typedef GLint (*PFNGLGETATTRIBLOCATIONPROC)(GLuint program, const GLchar *name);
    typedef void (*PFNGLENABLEVERTEXATTRIBARRAYPROC)(GLuint index);
    typedef void (*PFNGLVERTEXATTRIBPOINTERPROC)(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer);
');

// Get module handle
$hInstance = $kernel32->GetModuleHandleW(null);

// Get DefWindowProcW address
$user32DllName = wbuf("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = abuf("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

// Prepare class name and window name
$className  = wbuf("PHPOpenGL20Window");
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
 * Get OpenGL extension function
 */
function getGLFunc($opengl32, $glext, string $name, string $type)
{
    $namePtr = abuf($name);
    $proc = $opengl32->wglGetProcAddress(FFI::cast('char*', FFI::addr($namePtr[0])));
    if ($proc === null) {
        echo "Failed to get $name\n";
        return null;
    }
    return FFI::cast($glext->type($type), $proc);
}

// Enable OpenGL
$hRC = enableOpenGL($gdi32, $opengl32, $hDC);
if ($hRC === null) {
    echo "Failed to enable OpenGL\n";
    exit(1);
}

echo "OpenGL context created\n";

// Get OpenGL 2.0 extension functions
$glGenBuffers              = getGLFunc($opengl32, $glext, 'glGenBuffers', 'PFNGLGENBUFFERSPROC');
$glBindBuffer              = getGLFunc($opengl32, $glext, 'glBindBuffer', 'PFNGLBINDBUFFERPROC');
$glBufferData              = getGLFunc($opengl32, $glext, 'glBufferData', 'PFNGLBUFFERDATAPROC');
$glCreateShader            = getGLFunc($opengl32, $glext, 'glCreateShader', 'PFNGLCREATESHADERPROC');
$glShaderSource            = getGLFunc($opengl32, $glext, 'glShaderSource', 'PFNGLSHADERSOURCEPROC');
$glCompileShader           = getGLFunc($opengl32, $glext, 'glCompileShader', 'PFNGLCOMPILESHADERPROC');
$glGetShaderiv             = getGLFunc($opengl32, $glext, 'glGetShaderiv', 'PFNGLGETSHADERIVPROC');
$glGetShaderInfoLog        = getGLFunc($opengl32, $glext, 'glGetShaderInfoLog', 'PFNGLGETSHADERINFOLOGPROC');
$glCreateProgram           = getGLFunc($opengl32, $glext, 'glCreateProgram', 'PFNGLCREATEPROGRAMPROC');
$glAttachShader            = getGLFunc($opengl32, $glext, 'glAttachShader', 'PFNGLATTACHSHADERPROC');
$glLinkProgram             = getGLFunc($opengl32, $glext, 'glLinkProgram', 'PFNGLLINKPROGRAMPROC');
$glGetProgramiv            = getGLFunc($opengl32, $glext, 'glGetProgramiv', 'PFNGLGETPROGRAMIVPROC');
$glGetProgramInfoLog       = getGLFunc($opengl32, $glext, 'glGetProgramInfoLog', 'PFNGLGETPROGRAMINFOLOGPROC');
$glUseProgram              = getGLFunc($opengl32, $glext, 'glUseProgram', 'PFNGLUSEPROGRAMPROC');
$glGetAttribLocation       = getGLFunc($opengl32, $glext, 'glGetAttribLocation', 'PFNGLGETATTRIBLOCATIONPROC');
$glEnableVertexAttribArray = getGLFunc($opengl32, $glext, 'glEnableVertexAttribArray', 'PFNGLENABLEVERTEXATTRIBARRAYPROC');
$glVertexAttribPointer     = getGLFunc($opengl32, $glext, 'glVertexAttribPointer', 'PFNGLVERTEXATTRIBPOINTERPROC');

echo "OpenGL 2.0 functions loaded\n";

// Helper function to create C string
function cstr(string $s): FFI\CData
{
    $len = strlen($s) + 1;
    $buf = FFI::new("char[$len]", false);
    for ($i = 0; $i < strlen($s); $i++) {
        $buf[$i] = $s[$i];
    }
    $buf[strlen($s)] = "\0";
    return $buf;
}

// Shader sources (desktop GLSL - no precision qualifier for vertex shader)
$vertexSource = 
"#version 110
attribute vec3 position;
attribute vec3 color;
varying vec4 vColor;
void main()
{
    vColor = vec4(color, 1.0);
    gl_Position = vec4(position, 1.0);
}
";

$fragmentSource = 
"#version 110
varying vec4 vColor;
void main()
{
    gl_FragColor = vColor;
}
";

// Create VBOs
$vbo = FFI::new('uint32_t[2]');
$glGenBuffers(2, FFI::addr($vbo[0]));

echo "VBOs created: {$vbo[0]}, {$vbo[1]}\n";

// Vertex data
$vertices = FFI::new('float[9]');
$vertices[0] =  0.0; $vertices[1] =  0.5; $vertices[2] = 0.0;  // Top
$vertices[3] =  0.5; $vertices[4] = -0.5; $vertices[5] = 0.0;  // Bottom-right
$vertices[6] = -0.5; $vertices[7] = -0.5; $vertices[8] = 0.0;  // Bottom-left

// Color data
$colors = FFI::new('float[9]');
$colors[0] = 1.0; $colors[1] = 0.0; $colors[2] = 0.0;  // Red
$colors[3] = 0.0; $colors[4] = 1.0; $colors[5] = 0.0;  // Green
$colors[6] = 0.0; $colors[7] = 0.0; $colors[8] = 1.0;  // Blue

// Upload vertex data
$glBindBuffer(GL_ARRAY_BUFFER, $vbo[0]);
$glBufferData(GL_ARRAY_BUFFER, 9 * 4, FFI::addr($vertices[0]), GL_STATIC_DRAW);

// Upload color data
$glBindBuffer(GL_ARRAY_BUFFER, $vbo[1]);
$glBufferData(GL_ARRAY_BUFFER, 9 * 4, FFI::addr($colors[0]), GL_STATIC_DRAW);

echo "Buffer data uploaded\n";

// Helper function to check shader compilation
function checkShaderCompile($glGetShaderiv, $glGetShaderInfoLog, $shader, $name): bool
{
    $status = FFI::new('int32_t');
    $glGetShaderiv($shader, GL_COMPILE_STATUS, FFI::addr($status));
    
    if ($status->cdata == 0) {
        $logLength = FFI::new('int32_t');
        $glGetShaderiv($shader, GL_INFO_LOG_LENGTH, FFI::addr($logLength));
        
        if ($logLength->cdata > 0) {
            $log = FFI::new("char[{$logLength->cdata}]");
            $actualLength = FFI::new('int32_t');
            $glGetShaderInfoLog($shader, $logLength->cdata, FFI::addr($actualLength), FFI::addr($log[0]));
            
            $errorMsg = '';
            for ($i = 0; $i < $actualLength->cdata; $i++) {
                $errorMsg .= $log[$i];
            }
            echo "$name compilation error: $errorMsg\n";
        }
        return false;
    }
    return true;
}

// Helper function to check program link
function checkProgramLink($glGetProgramiv, $glGetProgramInfoLog, $program): bool
{
    $status = FFI::new('int32_t');
    $glGetProgramiv($program, GL_LINK_STATUS, FFI::addr($status));
    
    if ($status->cdata == 0) {
        $logLength = FFI::new('int32_t');
        $glGetProgramiv($program, GL_INFO_LOG_LENGTH, FFI::addr($logLength));
        
        if ($logLength->cdata > 0) {
            $log = FFI::new("char[{$logLength->cdata}]");
            $actualLength = FFI::new('int32_t');
            $glGetProgramInfoLog($program, $logLength->cdata, FFI::addr($actualLength), FFI::addr($log[0]));
            
            $errorMsg = '';
            for ($i = 0; $i < $actualLength->cdata; $i++) {
                $errorMsg .= $log[$i];
            }
            echo "Program link error: $errorMsg\n";
        }
        return false;
    }
    return true;
}

// Create and compile vertex shader
$vertexShader = $glCreateShader(GL_VERTEX_SHADER);
$vsSourceStr = cstr($vertexSource);
$vsSourcePtr = FFI::new('char*[1]');
$vsSourcePtr[0] = FFI::cast('char*', FFI::addr($vsSourceStr[0]));
$glShaderSource($vertexShader, 1, FFI::addr($vsSourcePtr[0]), null);
$glCompileShader($vertexShader);

if (!checkShaderCompile($glGetShaderiv, $glGetShaderInfoLog, $vertexShader, "Vertex shader")) {
    exit(1);
}
echo "Vertex shader compiled successfully\n";

// Create and compile fragment shader
$fragmentShader = $glCreateShader(GL_FRAGMENT_SHADER);
$fsSourceStr = cstr($fragmentSource);
$fsSourcePtr = FFI::new('char*[1]');
$fsSourcePtr[0] = FFI::cast('char*', FFI::addr($fsSourceStr[0]));
$glShaderSource($fragmentShader, 1, FFI::addr($fsSourcePtr[0]), null);
$glCompileShader($fragmentShader);

if (!checkShaderCompile($glGetShaderiv, $glGetShaderInfoLog, $fragmentShader, "Fragment shader")) {
    exit(1);
}
echo "Fragment shader compiled successfully\n";

echo "Fragment shader compiled successfully\n";

// Create and link shader program
$shaderProgram = $glCreateProgram();
$glAttachShader($shaderProgram, $vertexShader);
$glAttachShader($shaderProgram, $fragmentShader);
$glLinkProgram($shaderProgram);

if (!checkProgramLink($glGetProgramiv, $glGetProgramInfoLog, $shaderProgram)) {
    exit(1);
}
$glUseProgram($shaderProgram);

echo "Shader program linked and active\n";

// Get attribute locations
$positionNameStr = cstr("position");
$posAttrib = $glGetAttribLocation($shaderProgram, FFI::cast('char*', FFI::addr($positionNameStr[0])));

$colorNameStr = cstr("color");
$colAttrib = $glGetAttribLocation($shaderProgram, FFI::cast('char*', FFI::addr($colorNameStr[0])));

echo "Attribute locations: position=$posAttrib, color=$colAttrib\n";

// Enable vertex attribute arrays
$glEnableVertexAttribArray($posAttrib);
$glEnableVertexAttribArray($colAttrib);

echo "OpenGL 2.0 initialized successfully\n";

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

        // Bind position buffer and set attribute pointer
        $glBindBuffer(GL_ARRAY_BUFFER, $vbo[0]);
        $glVertexAttribPointer($posAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

        // Bind color buffer and set attribute pointer
        $glBindBuffer(GL_ARRAY_BUFFER, $vbo[1]);
        $glVertexAttribPointer($colAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

        // Draw triangle
        $opengl32->glDrawArrays(GL_TRIANGLES, 0, 3);

        $gdi32->SwapBuffers($hDC);

        $kernel32->Sleep(1);
    }
}

// Cleanup
disableOpenGL($opengl32, $user32, $hwnd, $hDC, $hRC);
$user32->DestroyWindow($hwnd);

echo "Program ended normally\n";
