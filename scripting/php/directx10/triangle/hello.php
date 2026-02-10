<?php
declare(strict_types=1);

/*
  DirectX 10 Triangle Drawing via PHP FFI

  Uses Direct3D10 COM interfaces via vtable.
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

// D3D10 / DXGI constants
const D3D10_SDK_VERSION = 29;
const D3D10_CREATE_DEVICE_DEBUG = 0x00000002;

const D3D_DRIVER_TYPE_HARDWARE  = 1;
const D3D_DRIVER_TYPE_REFERENCE = 2;
const D3D_DRIVER_TYPE_WARP      = 5;

const DXGI_FORMAT_R8G8B8A8_UNORM     = 28;
const DXGI_FORMAT_R32G32B32_FLOAT    = 6;
const DXGI_FORMAT_R32G32B32A32_FLOAT = 2;

const DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x00000020;

const D3D10_USAGE_DEFAULT       = 0;
const D3D10_BIND_VERTEX_BUFFER  = 0x00000001;
const D3D10_INPUT_PER_VERTEX_DATA = 0;
const D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST = 4;

// Rasterizer state constants
const D3D10_FILL_WIREFRAME = 2;
const D3D10_FILL_SOLID     = 3;
const D3D10_CULL_NONE      = 1;

const D3DCOMPILE_ENABLE_STRICTNESS = 0x00000800;

// COM vtable indices
const VTBL_RELEASE = 2;

// IDXGISwapChain
const VTBL_SWAP_PRESENT = 8;
const VTBL_SWAP_GETBUFFER = 9;

// ID3D10Device (Device acts as both device and context in DX10)
const VTBL_DEVICE_PS_SET_SHADER = 5;
const VTBL_DEVICE_VS_SET_SHADER = 7;
const VTBL_DEVICE_DRAW = 9;
const VTBL_DEVICE_IA_SET_INPUT_LAYOUT = 11;
const VTBL_DEVICE_IA_SET_VERTEX_BUFFERS = 12;
const VTBL_DEVICE_IA_SET_PRIMITIVE_TOPOLOGY = 18;
const VTBL_DEVICE_OM_SET_RENDER_TARGETS = 24;
const VTBL_DEVICE_RS_SET_STATE = 29;
const VTBL_DEVICE_RS_SET_VIEWPORTS = 30;
const VTBL_DEVICE_CLEAR_RTV = 35;
const VTBL_DEVICE_CREATE_BUFFER = 71;
const VTBL_DEVICE_CREATE_RTV = 76;
const VTBL_DEVICE_CREATE_INPUT_LAYOUT = 78;
const VTBL_DEVICE_CREATE_VS = 79;
const VTBL_DEVICE_CREATE_PS = 82;
const VTBL_DEVICE_CREATE_RASTERIZER_STATE = 85;

// ID3DBlob
const VTBL_BLOB_GET_PTR = 3;
const VTBL_BLOB_GET_SIZE = 4;

function wstr(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

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
    BOOL IsWindow(HWND hWnd);

    BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageW(const MSG *lpMsg);

    HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
    HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);

    BOOL GetClientRect(HWND hWnd, RECT* lpRect);
', 'user32.dll');

// d3d10 types
$sizeType = PHP_INT_SIZE === 8 ? 'unsigned long long' : 'unsigned long';
$d3d10Cdef = <<<CDEF
    typedef long HRESULT;
    typedef {$sizeType} SIZE_T;
    typedef {$sizeType} UINTPTR;
    typedef void* HWND;

    typedef struct _GUID {
        uint32_t Data1;
        uint16_t Data2;
        uint16_t Data3;
        uint8_t  Data4[8];
    } GUID;

    typedef struct DXGI_RATIONAL {
        uint32_t Numerator;
        uint32_t Denominator;
    } DXGI_RATIONAL;

    typedef struct DXGI_MODE_DESC {
        uint32_t Width;
        uint32_t Height;
        DXGI_RATIONAL RefreshRate;
        uint32_t Format;
        uint32_t ScanlineOrdering;
        uint32_t Scaling;
    } DXGI_MODE_DESC;

    typedef struct DXGI_SAMPLE_DESC {
        uint32_t Count;
        uint32_t Quality;
    } DXGI_SAMPLE_DESC;

    typedef struct DXGI_SWAP_CHAIN_DESC {
        DXGI_MODE_DESC BufferDesc;
        DXGI_SAMPLE_DESC SampleDesc;
        uint32_t BufferUsage;
        uint32_t BufferCount;
        HWND OutputWindow;
        int Windowed;
        uint32_t SwapEffect;
        uint32_t Flags;
    } DXGI_SWAP_CHAIN_DESC;

    // D3D10_VIEWPORT uses integers for position/size, floats for depth
    typedef struct D3D10_VIEWPORT {
        int32_t TopLeftX;
        int32_t TopLeftY;
        uint32_t Width;
        uint32_t Height;
        float MinDepth;
        float MaxDepth;
    } D3D10_VIEWPORT;

    typedef struct D3D10_BUFFER_DESC {
        uint32_t ByteWidth;
        uint32_t Usage;
        uint32_t BindFlags;
        uint32_t CPUAccessFlags;
        uint32_t MiscFlags;
        uint32_t StructureByteStride;
    } D3D10_BUFFER_DESC;

    typedef struct D3D10_SUBRESOURCE_DATA {
        void* pSysMem;
        uint32_t SysMemPitch;
        uint32_t SysMemSlicePitch;
    } D3D10_SUBRESOURCE_DATA;

    typedef struct D3D10_INPUT_ELEMENT_DESC {
        const char* SemanticName;
        uint32_t SemanticIndex;
        uint32_t Format;
        uint32_t InputSlot;
        uint32_t AlignedByteOffset;
        uint32_t InputSlotClass;
        uint32_t InstanceDataStepRate;
    } D3D10_INPUT_ELEMENT_DESC;

    typedef struct D3D10_RASTERIZER_DESC {
        uint32_t FillMode;
        uint32_t CullMode;
        int32_t FrontCounterClockwise;
        int32_t DepthBias;
        float DepthBiasClamp;
        float SlopeScaledDepthBias;
        int32_t DepthClipEnable;
        int32_t ScissorEnable;
        int32_t MultisampleEnable;
        int32_t AntialiasedLineEnable;
    } D3D10_RASTERIZER_DESC;

    typedef struct IUnknown {
        void** lpVtbl;
    } IUnknown;

    typedef HRESULT (__stdcall *ReleaseFunc)(void* pThis);
    typedef HRESULT (__stdcall *D3D10CreateDeviceAndSwapChainFunc)(
        void* pAdapter,
        uint32_t DriverType,
        void* Software,
        uint32_t Flags,
        uint32_t SDKVersion,
        DXGI_SWAP_CHAIN_DESC* pSwapChainDesc,
        void** ppSwapChain,
        void** ppDevice
    );

    typedef HRESULT (__stdcall *D3DCompileFunc)(
        const void* pSrcData,
        SIZE_T SrcDataSize,
        const char* pSourceName,
        const void* pDefines,
        const void* pInclude,
        const char* pEntrypoint,
        const char* pTarget,
        uint32_t Flags1,
        uint32_t Flags2,
        void** ppCode,
        void** ppErrorMsgs
    );

    typedef HRESULT (__stdcall *CreateRenderTargetViewFunc)(void* pThis, void* pResource, void* pDesc, void** ppRTView);
    typedef HRESULT (__stdcall *CreateBufferFunc)(void* pThis, D3D10_BUFFER_DESC* pDesc, D3D10_SUBRESOURCE_DATA* pInitialData, void** ppBuffer);
    typedef HRESULT (__stdcall *CreateInputLayoutFunc)(void* pThis, D3D10_INPUT_ELEMENT_DESC* pDesc, uint32_t NumElements, const void* pShaderBytecodeWithInputSignature, SIZE_T BytecodeLength, void** ppInputLayout);
    typedef HRESULT (__stdcall *CreateVertexShaderFunc)(void* pThis, const void* pShaderBytecode, SIZE_T BytecodeLength, void** ppVertexShader);
    typedef HRESULT (__stdcall *CreatePixelShaderFunc)(void* pThis, const void* pShaderBytecode, SIZE_T BytecodeLength, void** ppPixelShader);
    typedef HRESULT (__stdcall *CreateRasterizerStateFunc)(void* pThis, D3D10_RASTERIZER_DESC* pDesc, void** ppRasterizerState);

    typedef HRESULT (__stdcall *GetBufferFunc)(void* pThis, uint32_t Buffer, const GUID* riid, void** ppSurface);
    typedef void (__stdcall *OMSetRenderTargetsFunc)(void* pThis, uint32_t NumViews, void** ppRenderTargetViews, void* pDepthStencilView);
    typedef void (__stdcall *RSSetViewportsFunc)(void* pThis, uint32_t NumViewports, D3D10_VIEWPORT* pViewports);
    typedef void (__stdcall *RSSetStateFunc)(void* pThis, void* pRasterizerState);
    typedef void (__stdcall *IASetInputLayoutFunc)(void* pThis, void* pInputLayout);
    typedef void (__stdcall *IASetVertexBuffersFunc)(void* pThis, uint32_t StartSlot, uint32_t NumBuffers, void** ppVertexBuffers, uint32_t* pStrides, uint32_t* pOffsets);
    typedef void (__stdcall *IASetPrimitiveTopologyFunc)(void* pThis, uint32_t Topology);
    typedef void (__stdcall *VSSetShaderFunc)(void* pThis, void* pVS);
    typedef void (__stdcall *PSSetShaderFunc)(void* pThis, void* pPS);
    typedef void (__stdcall *DrawFunc)(void* pThis, uint32_t VertexCount, uint32_t StartVertexLocation);
    typedef void (__stdcall *ClearRenderTargetViewFunc)(void* pThis, void* pRenderTargetView, const float* ColorRGBA);
    typedef HRESULT (__stdcall *PresentFunc)(void* pThis, uint32_t SyncInterval, uint32_t Flags);

    typedef void* (__stdcall *GetBufferPointerFunc)(void* pThis);
    typedef SIZE_T (__stdcall *GetBufferSizeFunc)(void* pThis);
CDEF;

$d3d10Types = FFI::cdef($d3d10Cdef);

// HLSL source
$HLSL_SRC = <<<HLSL
struct VS_OUTPUT
{
    float4 position : SV_POSITION;
    float4 color : COLOR0;
};

VS_OUTPUT VS(float4 position : POSITION, float4 color : COLOR)
{
    VS_OUTPUT output = (VS_OUTPUT)0;
    output.position = position;
    output.color = color;
    return output;
}

float4 PS(VS_OUTPUT input) : SV_Target
{
    return input.color;
}
HLSL;

function guid_from_string(string $s, FFI $ffi): FFI\CData
{
    $s = trim($s, "{} ");
    $parts = explode('-', $s);
    $g = $ffi->new('GUID');
    $g->Data1 = hexdec($parts[0]);
    $g->Data2 = hexdec($parts[1]);
    $g->Data3 = hexdec($parts[2]);

    $d4 = hex2bin($parts[3] . $parts[4]);
    for ($i = 0; $i < 8; $i++) {
        $g->Data4[$i] = ord($d4[$i]);
    }
    return $g;
}

function com_release(FFI $ffi, ?FFI\CData $obj): void
{
    if ($obj === null) {
        return;
    }
    try {
        $addr = (int)FFI::cast($ffi->type('UINTPTR'), $obj)->cdata;
        if ($addr === 0) {
            return;
        }
    } catch (Throwable $e) {
        return;
    }
    $fn = FFI::cast($ffi->type('ReleaseFunc'), $obj->lpVtbl[VTBL_RELEASE]);
    $fn($obj);
}

function blob_ptr(FFI $ffi, FFI\CData $blob): FFI\CData
{
    $fn = FFI::cast($ffi->type('GetBufferPointerFunc'), $blob->lpVtbl[VTBL_BLOB_GET_PTR]);
    return $fn($blob);
}

function blob_size(FFI $ffi, FFI\CData $blob): int
{
    $fn = FFI::cast($ffi->type('GetBufferSizeFunc'), $blob->lpVtbl[VTBL_BLOB_GET_SIZE]);
    return (int)$fn($blob);
}

function deref_void_ptr(FFI $ffi, FFI\CData $ptr): ?FFI\CData
{
    $pp = FFI::cast('void**', FFI::addr($ptr));
    return $pp[0];
}

function ptr_hex(FFI $ffi, FFI\CData $ptr): string
{
    $addr = $ptr;
    try {
        $addr = FFI::addr($ptr[0]);
    } catch (Throwable $e) {
        // Keep original pointer if not an array-like CData.
    }
    $val = (int)FFI::cast($ffi->type('UINTPTR'), $addr)->cdata;
    return '0x' . dechex($val);
}

function compile_hlsl(FFI $ffi, FFI $d3dcompiler, string $src, string $entry, string $target): FFI\CData
{
    $srcLen = strlen($src) + 1;
    $srcBuf = FFI::new("char[$srcLen]", false);
    FFI::memcpy($srcBuf, $src, $srcLen - 1);
    $srcBuf[$srcLen - 1] = "\0";

    $nameStr = "embedded.hlsl\0";
    $nameBuf = FFI::new("char[" . strlen($nameStr) . "]", false);
    FFI::memcpy($nameBuf, $nameStr, strlen($nameStr));

    $entryStr = $entry . "\0";
    $entryBuf = FFI::new("char[" . strlen($entryStr) . "]", false);
    FFI::memcpy($entryBuf, $entryStr, strlen($entryStr));

    $targetStr = $target . "\0";
    $targetBuf = FFI::new("char[" . strlen($targetStr) . "]", false);
    FFI::memcpy($targetBuf, $targetStr, strlen($targetStr));

    $code = FFI::new('void*');
    $err = FFI::new('void*');

    echo "[Compile] entry=$entry target=$target\n";

    $fn = FFI::cast($ffi->type('D3DCompileFunc'), $d3dcompiler->D3DCompile);
    $hr = $fn(
        $srcBuf,
        $srcLen - 1,
        $nameBuf,
        null,
        null,
        $entryBuf,
        $targetBuf,
        D3DCOMPILE_ENABLE_STRICTNESS,
        0,
        FFI::addr($code),
        FFI::addr($err)
    );

    $codePtr = deref_void_ptr($ffi, $code);
    $errPtr = deref_void_ptr($ffi, $err);

    if ($hr < 0) {
        $msg = "D3DCompile failed";
        if ($errPtr !== null && (int)FFI::cast($ffi->type('UINTPTR'), $errPtr)->cdata !== 0) {
            $blob = FFI::cast($ffi->type('IUnknown*'), $errPtr);
            $ptr = blob_ptr($ffi, $blob);
            $size = blob_size($ffi, $blob);
            if ($ptr && $size > 0) {
                $msg = FFI::string($ptr, $size);
            }
            com_release($ffi, $blob);
        }
        throw new RuntimeException($msg);
    }

    if ($codePtr === null) {
        throw new RuntimeException('D3DCompile returned null code blob');
    }

    return FFI::cast($ffi->type('IUnknown*'), $codePtr);
}

// Window setup
$hInstance = $kernel32->GetModuleHandleW(null);

$user32DllName = wstr("user32.dll");
$hUser32 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($user32DllName[0])));
$procName = astr("DefWindowProcW");
$defWndProcAddr = $kernel32->GetProcAddress($hUser32, FFI::cast('char*', FFI::addr($procName[0])));

$className  = wstr("PHPD3D10Window");
$windowName = wstr("Hello, World! (PHP DirectX10)");

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

// Load d3d10.dll and d3dcompiler
$d3d10DllName = wstr("d3d10.dll");
$hD3D10 = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3d10DllName[0])));
if ($hD3D10 === null) {
    echo "Failed to load d3d10.dll\n";
    exit(1);
}

echo "d3d10.dll loaded\n";

$d3dcompilerDllName = wstr("d3dcompiler_47.dll");
$hD3DCompiler = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3dcompilerDllName[0])));
if ($hD3DCompiler === null) {
    $d3dcompilerDllName = wstr("d3dcompiler_43.dll");
    $hD3DCompiler = $kernel32->LoadLibraryW(FFI::cast('uint16_t*', FFI::addr($d3dcompilerDllName[0])));
}
if ($hD3DCompiler === null) {
    echo "Failed to load d3dcompiler_47/43.dll\n";
    exit(1);
}

echo "d3dcompiler loaded\n";

$pfnCreateDeviceAndSwapChain = $kernel32->GetProcAddress($hD3D10, "D3D10CreateDeviceAndSwapChain\0");
if ($pfnCreateDeviceAndSwapChain === null) {
    echo "Failed to get D3D10CreateDeviceAndSwapChain\n";
    exit(1);
}

$compilerCdef = "typedef long HRESULT; typedef {$sizeType} SIZE_T; HRESULT D3DCompile(const void* pSrcData, SIZE_T SrcDataSize, const char* pSourceName, const void* pDefines, const void* pInclude, const char* pEntrypoint, const char* pTarget, uint32_t Flags1, uint32_t Flags2, void** ppCode, void** ppErrorMsgs);";
try {
    $d3dcompiler = FFI::cdef($compilerCdef, 'd3dcompiler_47.dll');
} catch (Throwable $e) {
    $d3dcompiler = FFI::cdef($compilerCdef, 'd3dcompiler_43.dll');
}

$createDeviceAndSwapChain = FFI::cast($d3d10Types->type('D3D10CreateDeviceAndSwapChainFunc'), $pfnCreateDeviceAndSwapChain);

// Swap chain desc
$rect = $user32->new('RECT');
$user32->GetClientRect($hwnd, FFI::addr($rect));
$width = $rect->right - $rect->left;
$height = $rect->bottom - $rect->top;
$width = $width > 0 ? $width : 640;
$height = $height > 0 ? $height : 480;

echo "Client rect: {$width} x {$height}\n";

$sd = $d3d10Types->new('DXGI_SWAP_CHAIN_DESC');
$sd->BufferCount = 1;
$sd->BufferDesc->Width = $width;
$sd->BufferDesc->Height = $height;
$sd->BufferDesc->RefreshRate->Numerator = 60;
$sd->BufferDesc->RefreshRate->Denominator = 1;
$sd->BufferDesc->Format = DXGI_FORMAT_R8G8B8A8_UNORM;
$sd->BufferDesc->ScanlineOrdering = 0;
$sd->BufferDesc->Scaling = 0;
$sd->SampleDesc->Count = 1;
$sd->SampleDesc->Quality = 0;
$sd->BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
$sd->OutputWindow = $hwnd;
$sd->Windowed = 1;
$sd->SwapEffect = 0;
$sd->Flags = 0;

$ppSwap = FFI::new('void*');
$ppDevice = FFI::new('void*');

// D3D10 doesn't have feature levels or separate context
$driverTypes = [D3D_DRIVER_TYPE_HARDWARE, D3D_DRIVER_TYPE_WARP, D3D_DRIVER_TYPE_REFERENCE];
$hr = -1;
$debugEnabled = false;

foreach ($driverTypes as $dt) {
    // Try with debug layer first
    $hr = $createDeviceAndSwapChain(
        null,
        $dt,
        null,
        D3D10_CREATE_DEVICE_DEBUG,
        D3D10_SDK_VERSION,
        FFI::addr($sd),
        FFI::addr($ppSwap),
        FFI::addr($ppDevice)
    );
    if ($hr >= 0) {
        $debugEnabled = true;
        echo "Device created with DEBUG layer\n";
        break;
    }

    // Try without debug
    $hr = $createDeviceAndSwapChain(
        null,
        $dt,
        null,
        0,
        D3D10_SDK_VERSION,
        FFI::addr($sd),
        FFI::addr($ppSwap),
        FFI::addr($ppDevice)
    );
    if ($hr >= 0) {
        break;
    }
}

if ($hr < 0) {
    echo "D3D10CreateDeviceAndSwapChain failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}

echo "D3D10 device and swap chain created\n";

$pSwap = FFI::cast($d3d10Types->type('IUnknown*'), $ppSwap);
$pDevice = FFI::cast($d3d10Types->type('IUnknown*'), $ppDevice);

// Get back buffer (D3D10 uses different GUID)
$iidTex2D = guid_from_string('{9B7E4C04-342C-4106-A19F-4F2704F689F0}', $d3d10Types);
$ppBackBuf = FFI::new('void*');
$getBuffer = FFI::cast($d3d10Types->type('GetBufferFunc'), $pSwap->lpVtbl[VTBL_SWAP_GETBUFFER]);
echo "Getting back buffer...\n";
$hr = $getBuffer($pSwap, 0, FFI::addr($iidTex2D), FFI::addr($ppBackBuf));
if ($hr < 0) {
    echo "SwapChain.GetBuffer failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
echo "Back buffer acquired\n";

// Create RTV
$ppRTV = FFI::new('void*');
$createRTV = FFI::cast($d3d10Types->type('CreateRenderTargetViewFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CREATE_RTV]);
echo "Creating render target view...\n";
$hr = $createRTV($pDevice, $ppBackBuf, null, FFI::addr($ppRTV));
if ($hr < 0) {
    echo "CreateRenderTargetView failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
$backBuf = FFI::cast($d3d10Types->type('IUnknown*'), $ppBackBuf);
com_release($d3d10Types, $backBuf);

$rtv = FFI::cast($d3d10Types->type('IUnknown*'), $ppRTV);
echo "Render target view created\n";

// Bind RTV (D3D10 uses device directly, not context)
$rtvArr = FFI::new('void*[1]');
$rtvArr[0] = FFI::cast('void*', $rtv);
$omSet = FFI::cast($d3d10Types->type('OMSetRenderTargetsFunc'), $pDevice->lpVtbl[VTBL_DEVICE_OM_SET_RENDER_TARGETS]);
$omSet($pDevice, 1, $rtvArr, null);

// Viewport (D3D10_VIEWPORT uses int for position/size)
$vp = $d3d10Types->new('D3D10_VIEWPORT');
$vp->TopLeftX = 0;
$vp->TopLeftY = 0;
$vp->Width = $width;
$vp->Height = $height;
$vp->MinDepth = 0.0;
$vp->MaxDepth = 1.0;

$rsSet = FFI::cast($d3d10Types->type('RSSetViewportsFunc'), $pDevice->lpVtbl[VTBL_DEVICE_RS_SET_VIEWPORTS]);
echo "Setting viewport...\n";
$rsSet($pDevice, 1, FFI::addr($vp));

// Compile shaders (use vs_4_0/ps_4_0 for D3D10)
echo "Compiling shaders...\n";
$vsBlob = compile_hlsl($d3d10Types, $d3dcompiler, $HLSL_SRC, 'VS', 'vs_4_0');
$psBlob = compile_hlsl($d3d10Types, $d3dcompiler, $HLSL_SRC, 'PS', 'ps_4_0');
echo "Shaders compiled\n";

// Create shaders (D3D10 CreateVertexShader/CreatePixelShader have different signature - no class linkage)
$createVS = FFI::cast($d3d10Types->type('CreateVertexShaderFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CREATE_VS]);
$createPS = FFI::cast($d3d10Types->type('CreatePixelShaderFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CREATE_PS]);

$ppVS = FFI::new('void*');
$ppPS = FFI::new('void*');

echo "Creating vertex shader...\n";
$vsPtr = blob_ptr($d3d10Types, $vsBlob);
$vsSize = blob_size($d3d10Types, $vsBlob);
$hr = $createVS($pDevice, $vsPtr, $vsSize, FFI::addr($ppVS));
if ($hr < 0) {
    echo "CreateVertexShader failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}

echo "Creating pixel shader...\n";
$psPtr = blob_ptr($d3d10Types, $psBlob);
$psSize = blob_size($d3d10Types, $psBlob);
$hr = $createPS($pDevice, $psPtr, $psSize, FFI::addr($ppPS));
if ($hr < 0) {
    echo "CreatePixelShader failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
echo "Shaders created\n";

$vs = FFI::cast($d3d10Types->type('IUnknown*'), $ppVS);
$ps = FFI::cast($d3d10Types->type('IUnknown*'), $ppPS);

// Input layout
$posSem = astr('POSITION');
$colSem = astr('COLOR');
$layout = $d3d10Types->new('D3D10_INPUT_ELEMENT_DESC[2]');
$layout[0]->SemanticName = FFI::cast('char*', FFI::addr($posSem[0]));
$layout[0]->SemanticIndex = 0;
$layout[0]->Format = DXGI_FORMAT_R32G32B32_FLOAT;
$layout[0]->InputSlot = 0;
$layout[0]->AlignedByteOffset = 0;
$layout[0]->InputSlotClass = D3D10_INPUT_PER_VERTEX_DATA;
$layout[0]->InstanceDataStepRate = 0;

$layout[1]->SemanticName = FFI::cast('char*', FFI::addr($colSem[0]));
$layout[1]->SemanticIndex = 0;
$layout[1]->Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
$layout[1]->InputSlot = 0;
$layout[1]->AlignedByteOffset = 12;
$layout[1]->InputSlotClass = D3D10_INPUT_PER_VERTEX_DATA;
$layout[1]->InstanceDataStepRate = 0;

$ppLayout = FFI::new('void*');
$createLayout = FFI::cast($d3d10Types->type('CreateInputLayoutFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CREATE_INPUT_LAYOUT]);
echo "Creating input layout...\n";
$hr = $createLayout(
    $pDevice,
    FFI::addr($layout[0]),
    2,
    blob_ptr($d3d10Types, $vsBlob),
    blob_size($d3d10Types, $vsBlob),
    FFI::addr($ppLayout)
);
if ($hr < 0) {
    echo "CreateInputLayout failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
echo "Input layout created\n";

$inputLayout = FFI::cast($d3d10Types->type('IUnknown*'), $ppLayout);

// Release shader blobs
com_release($d3d10Types, $vsBlob);
com_release($d3d10Types, $psBlob);

$iaSetLayout = FFI::cast($d3d10Types->type('IASetInputLayoutFunc'), $pDevice->lpVtbl[VTBL_DEVICE_IA_SET_INPUT_LAYOUT]);
$iaSetLayout($pDevice, $inputLayout);

// Vertex buffer
$vertex = $d3d10Types->new('struct { float x,y,z,r,g,b,a; }[3]');
$vertex[0]->x = 0.0;  $vertex[0]->y = 0.5;  $vertex[0]->z = 0.5;  $vertex[0]->r = 1.0; $vertex[0]->g = 0.0; $vertex[0]->b = 0.0; $vertex[0]->a = 1.0;
$vertex[1]->x = 0.5;  $vertex[1]->y = -0.5; $vertex[1]->z = 0.5;  $vertex[1]->r = 0.0; $vertex[1]->g = 1.0; $vertex[1]->b = 0.0; $vertex[1]->a = 1.0;
$vertex[2]->x = -0.5; $vertex[2]->y = -0.5; $vertex[2]->z = 0.5;  $vertex[2]->r = 0.0; $vertex[2]->g = 0.0; $vertex[2]->b = 1.0; $vertex[2]->a = 1.0;

$bd = $d3d10Types->new('D3D10_BUFFER_DESC');
$bd->Usage = D3D10_USAGE_DEFAULT;
$bd->ByteWidth = FFI::sizeof($vertex);
$bd->BindFlags = D3D10_BIND_VERTEX_BUFFER;
$bd->CPUAccessFlags = 0;
$bd->MiscFlags = 0;
$bd->StructureByteStride = 0;

$initData = $d3d10Types->new('D3D10_SUBRESOURCE_DATA');
$initData->pSysMem = FFI::addr($vertex[0]);
$initData->SysMemPitch = 0;
$initData->SysMemSlicePitch = 0;

$ppVB = FFI::new('void*');
$createBuf = FFI::cast($d3d10Types->type('CreateBufferFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CREATE_BUFFER]);
echo "Creating vertex buffer...\n";
$hr = $createBuf($pDevice, FFI::addr($bd), FFI::addr($initData), FFI::addr($ppVB));
if ($hr < 0) {
    echo "CreateBuffer failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
echo "Vertex buffer created\n";

$vb = FFI::cast($d3d10Types->type('IUnknown*'), $ppVB);

$vbArr = FFI::new('void*[1]');
$vbArr[0] = FFI::cast('void*', $vb);
$strides = FFI::new('uint32_t[1]');
$offsets = FFI::new('uint32_t[1]');
$strides[0] = FFI::sizeof($vertex[0]);
$offsets[0] = 0;

$iaSetVB = FFI::cast($d3d10Types->type('IASetVertexBuffersFunc'), $pDevice->lpVtbl[VTBL_DEVICE_IA_SET_VERTEX_BUFFERS]);
$iaSetVB($pDevice, 0, 1, $vbArr, $strides, $offsets);

$iaSetTopo = FFI::cast($d3d10Types->type('IASetPrimitiveTopologyFunc'), $pDevice->lpVtbl[VTBL_DEVICE_IA_SET_PRIMITIVE_TOPOLOGY]);
$iaSetTopo($pDevice, D3D10_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

// Create and set rasterizer state (disable backface culling)
echo "Creating rasterizer state...\n";
$rsDesc = $d3d10Types->new('D3D10_RASTERIZER_DESC');
$rsDesc->FillMode = D3D10_FILL_SOLID;
$rsDesc->CullMode = D3D10_CULL_NONE;
$rsDesc->FrontCounterClockwise = 0;
$rsDesc->DepthBias = 0;
$rsDesc->DepthBiasClamp = 0.0;
$rsDesc->SlopeScaledDepthBias = 0.0;
$rsDesc->DepthClipEnable = 1;  // Required for D3D10
$rsDesc->ScissorEnable = 0;
$rsDesc->MultisampleEnable = 0;
$rsDesc->AntialiasedLineEnable = 0;

$ppRS = FFI::new('void*');
$createRS = FFI::cast($d3d10Types->type('CreateRasterizerStateFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CREATE_RASTERIZER_STATE]);
$hr = $createRS($pDevice, FFI::addr($rsDesc), FFI::addr($ppRS));
if ($hr >= 0) {
    $rs = FFI::cast($d3d10Types->type('IUnknown*'), $ppRS);
    $rsSetState = FFI::cast($d3d10Types->type('RSSetStateFunc'), $pDevice->lpVtbl[VTBL_DEVICE_RS_SET_STATE]);
    $rsSetState($pDevice, $rs);
    echo "Rasterizer state set (no culling, solid fill)\n";
} else {
    echo "Warning: CreateRasterizerState failed: " . sprintf("0x%08X", $hr) . "\n";
    $rs = null;
}

$user32->ShowWindow($hwnd, SW_SHOWDEFAULT);
$user32->UpdateWindow($hwnd);

echo "Starting message loop\n";

$msg = $user32->new('MSG');
$lastRedraw = 0.0;
$frameCount = 0;

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
        // Clear
        $clear = FFI::cast($d3d10Types->type('ClearRenderTargetViewFunc'), $pDevice->lpVtbl[VTBL_DEVICE_CLEAR_RTV]);
        $color = FFI::new('float[4]');
        $color[0] = 1.0; $color[1] = 1.0; $color[2] = 1.0; $color[3] = 1.0;
        $clear($pDevice, $rtv, $color);

        // Set shaders (D3D10 VSSetShader/PSSetShader take only shader pointer)
        $vsSet = FFI::cast($d3d10Types->type('VSSetShaderFunc'), $pDevice->lpVtbl[VTBL_DEVICE_VS_SET_SHADER]);
        $psSet = FFI::cast($d3d10Types->type('PSSetShaderFunc'), $pDevice->lpVtbl[VTBL_DEVICE_PS_SET_SHADER]);
        $vsSet($pDevice, $vs);
        $psSet($pDevice, $ps);

        // Draw
        $draw = FFI::cast($d3d10Types->type('DrawFunc'), $pDevice->lpVtbl[VTBL_DEVICE_DRAW]);
        $draw($pDevice, 3, 0);

        // Present
        $present = FFI::cast($d3d10Types->type('PresentFunc'), $pSwap->lpVtbl[VTBL_SWAP_PRESENT]);
        $present($pSwap, 0, 0);

        $lastRedraw = $now;
        $frameCount++;
    }

    $kernel32->Sleep(1);
}

echo "Total frames rendered: $frameCount\n";

// Cleanup
echo "Releasing resources...\n";
if (isset($rs) && $rs !== null) {
    com_release($d3d10Types, $rs);
}
com_release($d3d10Types, $vb);
com_release($d3d10Types, $inputLayout);
com_release($d3d10Types, $vs);
com_release($d3d10Types, $ps);
com_release($d3d10Types, $rtv);
com_release($d3d10Types, $pSwap);
com_release($d3d10Types, $pDevice);

$kernel32->FreeLibrary($hD3DCompiler);
$kernel32->FreeLibrary($hD3D10);

echo "Program ended normally\n";
