<?php
declare(strict_types=1);

/*
  DirectX 9 Triangle Drawing via PHP FFI

  Uses Direct3D9 COM interfaces via vtable.
  Draws a colored triangle using a vertex buffer.
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

const WM_QUIT             = 0x0012;
const PM_REMOVE           = 0x0001;

const IDI_APPLICATION     = 32512;
const IDC_ARROW           = 32512;

// DirectX 9 constants
const D3D_SDK_VERSION = 32;
const D3DADAPTER_DEFAULT = 0;
const D3DDEVTYPE_HAL = 1;
const D3DCREATE_SOFTWARE_VERTEXPROCESSING = 0x00000020;
const D3DFMT_UNKNOWN = 0;
const D3DSWAPEFFECT_DISCARD = 1;
const D3DPOOL_DEFAULT = 0;
const D3DCLEAR_TARGET = 0x00000001;
const D3DPT_TRIANGLELIST = 4;

// FVF flags
const D3DFVF_XYZRHW  = 0x004;
const D3DFVF_DIFFUSE = 0x040;
const D3DFVF_VERTEX  = D3DFVF_XYZRHW | D3DFVF_DIFFUSE;

// COM vtable indices
const VTBL_RELEASE = 2;

// IDirect3D9
const VTBL_D3D9_CREATE_DEVICE = 16;

// IDirect3DDevice9
const VTBL_DEVICE_PRESENT = 17;
const VTBL_DEVICE_CREATE_VERTEX_BUFFER = 26;
const VTBL_DEVICE_BEGIN_SCENE = 41;
const VTBL_DEVICE_END_SCENE = 42;
const VTBL_DEVICE_CLEAR = 43;
const VTBL_DEVICE_DRAW_PRIMITIVE = 81;
const VTBL_DEVICE_SET_FVF = 89;
const VTBL_DEVICE_SET_STREAM_SOURCE = 100;

// IDirect3DVertexBuffer9
const VTBL_VB_LOCK = 11;
const VTBL_VB_UNLOCK = 12;

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

function d3dcolor_xrgb(int $r, int $g, int $b): int
{
    return 0xFF000000 | (($r & 0xFF) << 16) | (($g & 0xFF) << 8) | ($b & 0xFF);
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
    BOOL IsWindow(HWND hWnd);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);
', 'user32.dll');

// d3d9.dll types
$d3d9Types = FFI::cdef('
    typedef long HRESULT;
    typedef void* HWND;

    typedef struct D3DPRESENT_PARAMETERS {
        uint32_t BackBufferWidth;
        uint32_t BackBufferHeight;
        uint32_t BackBufferFormat;
        uint32_t BackBufferCount;
        uint32_t MultiSampleType;
        uint32_t MultiSampleQuality;
        uint32_t SwapEffect;
        void*    hDeviceWindow;
        int      Windowed;
        int      EnableAutoDepthStencil;
        uint32_t AutoDepthStencilFormat;
        uint32_t Flags;
        uint32_t FullScreen_RefreshRateInHz;
        uint32_t PresentationInterval;
    } D3DPRESENT_PARAMETERS;

    typedef struct VERTEX {
        float x;
        float y;
        float z;
        float rhw;
        uint32_t color;
    } VERTEX;

    typedef struct IUnknown {
        void** lpVtbl;
    } IUnknown;

    typedef HRESULT (__stdcall *ReleaseFunc)(void* pThis);
    typedef void* (__stdcall *Direct3DCreate9Func)(uint32_t sdkVersion);

    typedef HRESULT (__stdcall *CreateDeviceFunc)(void* pThis, uint32_t Adapter, uint32_t DeviceType,
        HWND hFocusWindow, uint32_t BehaviorFlags, D3DPRESENT_PARAMETERS* pPresentationParameters,
        void** ppReturnedDeviceInterface);

    typedef HRESULT (__stdcall *CreateVertexBufferFunc)(void* pThis, uint32_t Length, uint32_t Usage,
        uint32_t FVF, uint32_t Pool, void** ppVertexBuffer, void* pSharedHandle);

    typedef HRESULT (__stdcall *BeginSceneFunc)(void* pThis);
    typedef HRESULT (__stdcall *EndSceneFunc)(void* pThis);
    typedef HRESULT (__stdcall *ClearFunc)(void* pThis, uint32_t Count, void* pRects, uint32_t Flags,
        uint32_t Color, float Z, uint32_t Stencil);
    typedef HRESULT (__stdcall *DrawPrimitiveFunc)(void* pThis, uint32_t PrimitiveType,
        uint32_t StartVertex, uint32_t PrimitiveCount);
    typedef HRESULT (__stdcall *SetFVFFunc)(void* pThis, uint32_t FVF);
    typedef HRESULT (__stdcall *SetStreamSourceFunc)(void* pThis, uint32_t StreamNumber, void* pStreamData,
        uint32_t OffsetInBytes, uint32_t Stride);
    typedef HRESULT (__stdcall *PresentFunc)(void* pThis, void* pSourceRect, void* pDestRect,
        HWND hDestWindowOverride, void* pDirtyRegion);

    typedef HRESULT (__stdcall *LockFunc)(void* pThis, uint32_t OffsetToLock, uint32_t SizeToLock,
        void** ppbData, uint32_t Flags);
    typedef HRESULT (__stdcall *UnlockFunc)(void* pThis);
');

// Window setup
$hInstance = $kernel32->GetModuleHandleW(null);

$user32DllName = wstr("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = astr("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

$className  = wstr("PHPD3D9Window");
$windowName = wstr("Hello, World! (PHP DirectX9)");

$hIcon   = $user32->LoadIconW(null, FFI::cast('uint16_t*', IDI_APPLICATION));
$hCursor = $user32->LoadCursorW(null, FFI::cast('uint16_t*', IDC_ARROW));

$wcex = $user32->new('WNDCLASSEXW');
$wcex->cbSize        = FFI::sizeof($wcex);
$wcex->style         = CS_HREDRAW | CS_VREDRAW;
$wcex->lpfnWndProc   = $defWndProcAddr;
$wcex->cbClsExtra    = 0;
$wcex->cbWndExtra    = 0;
$wcex->hInstance     = $hInstance;
$wcex->hIcon         = $hIcon;
$wcex->hCursor       = $hCursor;
$wcex->hbrBackground = null;
$wcex->lpszMenuName  = null;
$wcex->lpszClassName = FFI::cast('uint16_t*', FFI::addr($className[0]));
$wcex->hIconSm       = $hIcon;

$atom = $user32->RegisterClassExW(FFI::addr($wcex));
if ($atom === 0) {
    $err = $kernel32->GetLastError();
    echo "RegisterClassExW failed (error: $err)\n";
    exit(1);
}

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

// Load d3d9.dll
$d3d9DllName = wstr("d3d9.dll");
$hD3D9 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3d9DllName[0])));
if ($hD3D9 === null) {
    echo "Failed to load d3d9.dll\n";
    exit(1);
}

echo "d3d9.dll loaded\n";

// Get Direct3DCreate9
$d3dCreateName = astr("Direct3DCreate9");
$pfnDirect3DCreate9 = $kernel32->GetProcAddress($hD3D9, FFI::cast('char*', FFI::addr($d3dCreateName[0])));
if ($pfnDirect3DCreate9 === null) {
    echo "Failed to get Direct3DCreate9\n";
    exit(1);
}

$Direct3DCreate9 = FFI::cast($d3d9Types->type('Direct3DCreate9Func'), $pfnDirect3DCreate9);
$pD3D = $Direct3DCreate9(D3D_SDK_VERSION);
if ($pD3D === null) {
    echo "Direct3DCreate9 failed\n";
    exit(1);
}

$pD3D = FFI::cast($d3d9Types->type('IUnknown*'), $pD3D);
echo "IDirect3D9 created\n";

// Create device
$d3dpp = $d3d9Types->new('D3DPRESENT_PARAMETERS');
$d3dpp->BackBufferWidth = 0;
$d3dpp->BackBufferHeight = 0;
$d3dpp->BackBufferFormat = D3DFMT_UNKNOWN;
$d3dpp->BackBufferCount = 1;
$d3dpp->MultiSampleType = 0;
$d3dpp->MultiSampleQuality = 0;
$d3dpp->SwapEffect = D3DSWAPEFFECT_DISCARD;
$d3dpp->hDeviceWindow = $hwnd;
$d3dpp->Windowed = 1;
$d3dpp->EnableAutoDepthStencil = 0;
$d3dpp->AutoDepthStencilFormat = 0;
$d3dpp->Flags = 0;
$d3dpp->FullScreen_RefreshRateInHz = 0;
$d3dpp->PresentationInterval = 0;

$pfnCreateDevice = FFI::cast(
    $d3d9Types->type('CreateDeviceFunc'),
    $pD3D->lpVtbl[VTBL_D3D9_CREATE_DEVICE]
);

$ppDevice = FFI::new('void*');
$hr = $pfnCreateDevice(
    $pD3D,
    D3DADAPTER_DEFAULT,
    D3DDEVTYPE_HAL,
    $hwnd,
    D3DCREATE_SOFTWARE_VERTEXPROCESSING,
    FFI::addr($d3dpp),
    FFI::addr($ppDevice)
);

if ($hr < 0) {
    echo "CreateDevice failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}

$pDevice = FFI::cast($d3d9Types->type('IUnknown*'), $ppDevice);
echo "IDirect3DDevice9 created\n";

// Create vertex buffer
$pfnCreateVB = FFI::cast(
    $d3d9Types->type('CreateVertexBufferFunc'),
    $pDevice->lpVtbl[VTBL_DEVICE_CREATE_VERTEX_BUFFER]
);

$ppVB = FFI::new('void*');
$vertexSize = FFI::sizeof($d3d9Types->type('VERTEX'));
$vertexCount = 3;
$vbSize = $vertexSize * $vertexCount;

$hr = $pfnCreateVB(
    $pDevice,
    $vbSize,
    0,
    D3DFVF_VERTEX,
    D3DPOOL_DEFAULT,
    FFI::addr($ppVB),
    null
);

if ($hr < 0) {
    echo "CreateVertexBuffer failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}

$pVB = FFI::cast($d3d9Types->type('IUnknown*'), $ppVB);

$pfnLock = FFI::cast(
    $d3d9Types->type('LockFunc'),
    $pVB->lpVtbl[VTBL_VB_LOCK]
);
$pfnUnlock = FFI::cast(
    $d3d9Types->type('UnlockFunc'),
    $pVB->lpVtbl[VTBL_VB_UNLOCK]
);

$ppData = FFI::new('void*');
$hr = $pfnLock($pVB, 0, $vbSize, FFI::addr($ppData), 0);
if ($hr < 0) {
    echo "VertexBuffer Lock failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}

$vertices = $d3d9Types->new("VERTEX[$vertexCount]");
$vertices[0]->x = 320.0; $vertices[0]->y = 100.0; $vertices[0]->z = 0.0; $vertices[0]->rhw = 1.0; $vertices[0]->color = d3dcolor_xrgb(255, 0, 0);
$vertices[1]->x = 520.0; $vertices[1]->y = 380.0; $vertices[1]->z = 0.0; $vertices[1]->rhw = 1.0; $vertices[1]->color = d3dcolor_xrgb(0, 255, 0);
$vertices[2]->x = 120.0; $vertices[2]->y = 380.0; $vertices[2]->z = 0.0; $vertices[2]->rhw = 1.0; $vertices[2]->color = d3dcolor_xrgb(0, 0, 255);

FFI::memcpy($ppData, FFI::addr($vertices[0]), $vbSize);
$pfnUnlock($pVB);

echo "Vertex buffer created\n";

// Device methods
$pfnBeginScene = FFI::cast($d3d9Types->type('BeginSceneFunc'), $pDevice->lpVtbl[VTBL_DEVICE_BEGIN_SCENE]);
$pfnEndScene = FFI::cast($d3d9Types->type('EndSceneFunc'), $pDevice->lpVtbl[VTBL_DEVICE_END_SCENE]);
$pfnClear = FFI::cast($d3d9Types->type('ClearFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CLEAR]);
$pfnDrawPrimitive = FFI::cast($d3d9Types->type('DrawPrimitiveFunc'), $pDevice->lpVtbl[VTBL_DEVICE_DRAW_PRIMITIVE]);
$pfnSetFVF = FFI::cast($d3d9Types->type('SetFVFFunc'), $pDevice->lpVtbl[VTBL_DEVICE_SET_FVF]);
$pfnSetStreamSource = FFI::cast($d3d9Types->type('SetStreamSourceFunc'), $pDevice->lpVtbl[VTBL_DEVICE_SET_STREAM_SOURCE]);
$pfnPresent = FFI::cast($d3d9Types->type('PresentFunc'), $pDevice->lpVtbl[VTBL_DEVICE_PRESENT]);

$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

echo "Starting message loop\n";

$msg = $user32->new('MSG');
$lastRedraw = 0.0;

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

    $now = microtime(true);
    if ($now - $lastRedraw > 0.016) {
        $pfnClear($pDevice, 0, null, D3DCLEAR_TARGET, d3dcolor_xrgb(255, 255, 255), 1.0, 0);

        $hr = $pfnBeginScene($pDevice);
        if ($hr >= 0) {
            $pfnSetStreamSource($pDevice, 0, $pVB, 0, $vertexSize);
            $pfnSetFVF($pDevice, D3DFVF_VERTEX);
            $pfnDrawPrimitive($pDevice, D3DPT_TRIANGLELIST, 0, 1);
            $pfnEndScene($pDevice);
        }

        $pfnPresent($pDevice, null, null, null, null);
        $lastRedraw = $now;
    }

    $kernel32->Sleep(1);
}

// Cleanup
echo "Releasing resources...\n";
$pfnRelease = FFI::cast($d3d9Types->type('ReleaseFunc'), $pVB->lpVtbl[VTBL_RELEASE]);
$pfnRelease($pVB);

$pfnRelease = FFI::cast($d3d9Types->type('ReleaseFunc'), $pDevice->lpVtbl[VTBL_RELEASE]);
$pfnRelease($pDevice);

$pfnRelease = FFI::cast($d3d9Types->type('ReleaseFunc'), $pD3D->lpVtbl[VTBL_RELEASE]);
$pfnRelease($pD3D);

$kernel32->FreeLibrary($hD3D9);

echo "Program ended normally\n";
