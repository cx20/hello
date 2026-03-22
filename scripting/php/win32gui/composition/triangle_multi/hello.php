<?php
declare(strict_types=1);

/*
  DirectComposition multi-panel sample in PHP.

  This script follows the same architecture as the Python / Ruby / Perl samples:
  - One Win32 host window
  - One shared D3D11 device
  - One DirectComposition root visual
  - Three composition swap chains
    Panel 0: OpenGL 4.6 via WGL_NV_DX_interop
    Panel 1: Direct3D11 triangle
    Panel 2: Vulkan offscreen render copied through a D3D11 staging texture

  Notes:
  - This sample is intentionally low-level and uses raw COM vtable calls.
  - Source comments are in English as requested.
*/

error_reporting(E_ALL);
ini_set('display_errors', '1');

const PANEL_W = 320;
const PANEL_H = 480;
const WINDOW_W = PANEL_W * 3;
const WINDOW_H = PANEL_H;

const WS_OVERLAPPEDWINDOW = 0x00CF0000;
const CS_OWNDC = 0x0020;
const CW_USEDEFAULT = 0x80000000;
const SW_SHOW = 5;
const WM_QUIT = 0x0012;
const PM_REMOVE = 0x0001;

const PFD_TYPE_RGBA = 0;
const PFD_MAIN_PLANE = 0;
const PFD_DRAW_TO_WINDOW = 0x00000004;
const PFD_SUPPORT_OPENGL = 0x00000020;
const PFD_DOUBLEBUFFER = 0x00000001;

const GL_COLOR_BUFFER_BIT = 0x00004000;
const GL_TRIANGLES = 0x0004;
const GL_FALSE = 0;
const GL_FLOAT = 0x1406;
const GL_ARRAY_BUFFER = 0x8892;
const GL_STATIC_DRAW = 0x88E4;
const GL_VERTEX_SHADER = 0x8B31;
const GL_FRAGMENT_SHADER = 0x8B30;
const GL_COMPILE_STATUS = 0x8B81;
const GL_LINK_STATUS = 0x8B82;
const GL_INFO_LOG_LENGTH = 0x8B84;
const GL_VERSION = 0x1F02;
const GL_SHADING_LANGUAGE_VERSION = 0x8B8C;
const GL_FRAMEBUFFER = 0x8D40;
const GL_RENDERBUFFER = 0x8D41;
const GL_COLOR_ATTACHMENT0 = 0x8CE0;

const WGL_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
const WGL_CONTEXT_MINOR_VERSION_ARB = 0x2092;
const WGL_CONTEXT_PROFILE_MASK_ARB = 0x9126;
const WGL_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
const WGL_ACCESS_READ_WRITE_NV = 0x0001;

const D3D11_SDK_VERSION = 7;
const D3D_DRIVER_TYPE_HARDWARE = 1;
const D3D_FEATURE_LEVEL_11_0 = 0xB000;
const D3D11_CREATE_DEVICE_BGRA_SUPPORT = 0x20;
const D3D11_USAGE_STAGING = 3;
const D3D11_CPU_ACCESS_WRITE = 0x00010000;
const D3D11_MAP_WRITE = 2;

const DXGI_FORMAT_B8G8R8A8_UNORM = 87;
const DXGI_USAGE_RENDER_TARGET_OUTPUT = 0x20;
const DXGI_SCALING_STRETCH = 0;
const DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL = 3;
const DXGI_ALPHA_MODE_PREMULTIPLIED = 1;
const DXGI_ALPHA_MODE_IGNORE = 3;

const VK_SUCCESS = 0;
const VK_STRUCTURE_TYPE_APPLICATION_INFO = 0;
const VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;
const VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO = 2;
const VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO = 3;
const VK_STRUCTURE_TYPE_SUBMIT_INFO = 4;
const VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO = 5;
const VK_STRUCTURE_TYPE_FENCE_CREATE_INFO = 8;
const VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO = 12;
const VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO = 14;
const VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO = 15;
const VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO = 16;
const VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO = 18;
const VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO = 19;
const VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO = 20;
const VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO = 22;
const VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO = 23;
const VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO = 24;
const VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO = 26;
const VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO = 28;
const VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO = 30;
const VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO = 37;
const VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO = 38;
const VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO = 39;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO = 40;
const VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO = 42;
const VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO = 43;

const VK_QUEUE_GRAPHICS_BIT = 0x00000001;
const VK_IMAGE_ASPECT_COLOR_BIT = 0x00000001;
const VK_FORMAT_B8G8R8A8_UNORM = 44;
const VK_IMAGE_TYPE_2D = 1;
const VK_IMAGE_TILING_OPTIMAL = 0;
const VK_IMAGE_USAGE_TRANSFER_SRC_BIT = 0x00000001;
const VK_BUFFER_USAGE_TRANSFER_DST_BIT = 0x00000002;
const VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT = 0x00000010;
const VK_SHARING_MODE_EXCLUSIVE = 0;
const VK_IMAGE_LAYOUT_UNDEFINED = 0;
const VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = 2;
const VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL = 6;
const VK_IMAGE_VIEW_TYPE_2D = 1;
const VK_ATTACHMENT_LOAD_OP_CLEAR = 1;
const VK_ATTACHMENT_LOAD_OP_DONT_CARE = 2;
const VK_ATTACHMENT_STORE_OP_STORE = 0;
const VK_ATTACHMENT_STORE_OP_DONT_CARE = 1;
const VK_PIPELINE_BIND_POINT_GRAPHICS = 0;
const VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST = 3;
const VK_POLYGON_MODE_FILL = 0;
const VK_CULL_MODE_NONE = 0;
const VK_FRONT_FACE_COUNTER_CLOCKWISE = 1;
const VK_SAMPLE_COUNT_1_BIT = 1;
const VK_COLOR_COMPONENT_RGBA_BITS = 0xF;
const VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = 0x00000002;
const VK_COMMAND_BUFFER_LEVEL_PRIMARY = 0;
const VK_FENCE_CREATE_SIGNALED_BIT = 0x00000001;
const VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT = 0x00000001;
const VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT = 0x00000002;
const VK_MEMORY_PROPERTY_HOST_COHERENT_BIT = 0x00000004;

const SHADERC_VERTEX_SHADER = 0;
const SHADERC_FRAGMENT_SHADER = 1;
const SHADERC_STATUS_SUCCESS = 0;

const SCRIPT_DIR = __DIR__;

// Global basic types FFI context for helper functions.
// Built-in types (char, uint8_t, uint16_t, uintptr_t, int, void*, etc.) are
// natively available in PHP FFI — no typedef needed.
$basicTypes = FFI::cdef('');

// Wrapper to avoid the deprecated static FFI::new() call throughout the codebase.
function ffi_new(string $type, bool $owned = true): FFI\CData
{
    global $basicTypes;
    return $basicTypes->new($type, $owned);
}

function log_msg(string $msg, FFI $kernel32): void
{
    $text = "[PhpDComp] $msg";
    echo $text . PHP_EOL;
    $kernel32->OutputDebugStringA($text);
}

function wbuf(string $s): FFI\CData
{
    global $basicTypes;
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = $basicTypes->new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

function abuf(string $s): FFI\CData
{
    global $basicTypes;
    $len = strlen($s) + 1;
    $buf = $basicTypes->new("char[$len]", false);
    FFI::memcpy($buf, $s . "\0", $len);
    return $buf;
}

function cstr(string $s): FFI\CData
{
    return abuf($s);
}

function guid_from_string(string $s): FFI\CData
{
    global $basicTypes;
    $s = str_replace(['-', '{', '}'], '', $s);
    $b = hex2bin($s);
    $bytes = array_values(unpack('C*', $b));
    $le = [
        $bytes[3], $bytes[2], $bytes[1], $bytes[0],
        $bytes[5], $bytes[4],
        $bytes[7], $bytes[6],
        $bytes[8], $bytes[9], $bytes[10], $bytes[11],
        $bytes[12], $bytes[13], $bytes[14], $bytes[15],
    ];
    $buf = $basicTypes->new('uint8_t[16]', false);
    for ($i = 0; $i < 16; $i++) {
        $buf[$i] = $le[$i];
    }
    return $buf;
}

function ptr_i(FFI\CData $p): int
{
    global $basicTypes;
    // Cast through uint8_t* first: direct void* → uintptr_t cast is unreliable in PHP FFI.
    return (int)$basicTypes->cast('uintptr_t', $basicTypes->cast('uint8_t*', $p))->cdata;
}

function com_fn(FFI\CData $obj, int $index, string $type): FFI\CData
{
    global $basicTypes, $types;
    // Index the vtable via a triple-pointer cast (built-in type, use $basicTypes).
    $vtbl = $basicTypes->cast('void***', $obj)[0];
    // Cast the function pointer to the named typedef defined in the $types context.
    return $types->cast($type, $vtbl[$index]);
}

function com_release(FFI\CData $obj): void
{
    // FFI::isNull() is the correct way to check for a null COM pointer.
    if (FFI::isNull($obj)) {
        return;
    }
    $fn = com_fn($obj, 2, 'ReleaseFunc');
    $fn($obj);
}

function read_blob_string(FFI\CData $blob): string
{
    $getPtr = com_fn($blob, 3, 'BlobGetPtrFunc');
    $getSize = com_fn($blob, 4, 'BlobGetSizeFunc');
    $ptr = $getPtr($blob);
    $size = (int)$getSize($blob);
    return FFI::string($ptr, $size);
}

function vk_check(int $res, string $what): void
{
    if ($res !== VK_SUCCESS) {
        throw new RuntimeException("$what failed: VkResult=$res");
    }
}

// ---------------------------------------------------------------------------
// Raw byte-buffer helpers for building Vulkan structs (mirrors Perl approach).
// Vulkan structs are built as zeroed uint8_t arrays; field values are written
// at specific byte offsets that match the C ABI layout on 64-bit Windows.
// ---------------------------------------------------------------------------

function vk_buf(int $size): FFI\CData
{
    global $basicTypes;
    $buf = $basicTypes->new("uint8_t[$size]", false);
    FFI::memset($buf, 0, $size);
    return $buf;
}

function vk_write_u32(FFI\CData $buf, int $offset, int $value): void
{
    // FFI::memcpy accepts a PHP string as source; pack('V',...) gives LE uint32.
    FFI::memcpy(FFI::addr($buf[$offset]), pack('V', $value & 0xFFFFFFFF), 4);
}

function vk_write_u64(FFI\CData $buf, int $offset, int $value): void
{
    // pack('P',...) = unsigned 64-bit, machine byte order (LE on x86 Windows).
    // PHP negative ints are stored as two's complement, so -1 → 0xFFFF...FFFF. ✓
    FFI::memcpy(FFI::addr($buf[$offset]), pack('P', $value), 8);
}

function vk_write_f32(FFI\CData $buf, int $offset, float $value): void
{
    FFI::memcpy(FFI::addr($buf[$offset]), pack('f', $value), 4);
}

function vk_read_u32(FFI\CData $buf, int $offset): int
{
    // Read four bytes directly from the uint8_t[] array.
    return ((int)$buf[$offset])
         | ((int)$buf[$offset + 1] << 8)
         | ((int)$buf[$offset + 2] << 16)
         | ((int)$buf[$offset + 3] << 24);
}

function vk_read_u64(FFI\CData $buf, int $offset): int
{
    return vk_read_u32($buf, $offset) | (vk_read_u32($buf, $offset + 4) << 32);
}

// VkPhysicalDeviceMemoryProperties layout (64-bit Windows):
//   offset 0:   memoryTypeCount (uint32)
//   offset 4:   memoryTypes[32] — each 8 bytes: propertyFlags(4) + heapIndex(4)
//   offset 260: memoryHeapCount (uint32)
//   offset 264: memoryHeaps[16] — each 16 bytes: size(8) + flags(4) + pad(4)
//   total: 520 bytes
function find_vk_memory_type(FFI\CData $memProps, int $typeBits, int $requiredFlags): int
{
    $typeCount = vk_read_u32($memProps, 0);
    for ($i = 0; $i < $typeCount; $i++) {
        $flags = vk_read_u32($memProps, 4 + $i * 8);
        if (($typeBits & (1 << $i)) !== 0 && (($flags & $requiredFlags) === $requiredFlags)) {
            return $i;
        }
    }
    throw new RuntimeException('No suitable Vulkan memory type found');
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
    void OutputDebugStringA(const char* lpOutputString);
', 'kernel32.dll');

// Forward any PHP fatal error to DebugView before the process exits.
register_shutdown_function(static function () use ($kernel32): void {
    $e = error_get_last();
    if ($e !== null && in_array($e['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        $msg = sprintf('[PhpDComp] FATAL: %s in %s:%d', $e['message'], $e['file'], $e['line']);
        $kernel32->OutputDebugStringA($msg);
        echo $msg . PHP_EOL;
    }
});

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

    typedef const char* LPCSTR;

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

    typedef struct tagWNDCLASSEXA {
        UINT      cbSize;
        UINT      style;
        WNDPROC   lpfnWndProc;
        int       cbClsExtra;
        int       cbWndExtra;
        HINSTANCE hInstance;
        HICON     hIcon;
        HCURSOR   hCursor;
        HBRUSH    hbrBackground;
        LPCSTR    lpszMenuName;
        LPCSTR    lpszClassName;
        HICON     hIconSm;
    } WNDCLASSEXA;

    ATOM RegisterClassExA(const WNDCLASSEXA *lpwcx);

    HWND CreateWindowExA(
        DWORD     dwExStyle,
        LPCSTR    lpClassName,
        LPCSTR    lpWindowName,
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
    HDC GetDC(HWND hWnd);
    int ReleaseDC(HWND hWnd, HDC hdc);

    BOOL PeekMessageA(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
    BOOL TranslateMessage(const MSG *lpMsg);
    LRESULT DispatchMessageA(const MSG *lpMsg);

    LRESULT DefWindowProcA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
', 'user32.dll');

$gdi32 = FFI::cdef('
    typedef void* HDC;
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

    int ChoosePixelFormat(HDC hdc, const PIXELFORMATDESCRIPTOR *ppfd);
    BOOL SetPixelFormat(HDC hdc, int format, const PIXELFORMATDESCRIPTOR *ppfd);
', 'gdi32.dll');

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

    HGLRC wglCreateContext(HDC hdc);
    BOOL wglMakeCurrent(HDC hdc, HGLRC hglrc);
    BOOL wglDeleteContext(HGLRC hglrc);
    PROC wglGetProcAddress(const char *name);

    void glClearColor(GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha);
    void glClear(GLbitfield mask);
    void glViewport(GLint x, GLint y, GLsizei width, GLsizei height);
    const char* glGetString(unsigned int name);
    void glFlush(void);
', 'opengl32.dll');

$types = FFI::cdef('
    typedef long HRESULT;
    typedef unsigned int UINT;
    typedef unsigned long DWORD;
    typedef unsigned long long UINT64;
    typedef unsigned long long SIZE_T;

    typedef HRESULT (__stdcall *QueryInterfaceFunc)(void* self, const void* riid, void** out);
    typedef UINT (__stdcall *ReleaseFunc)(void* self);

    typedef HRESULT (__stdcall *GetAdapterFunc)(void* self, void** out);
    typedef HRESULT (__stdcall *GetParentFunc)(void* self, const void* riid, void** out);

    typedef HRESULT (__stdcall *CreateSwapChainForCompositionFunc)(void* self, void* device, const void* desc, void* restrictToOutput, void** out);
    typedef HRESULT (__stdcall *SwapGetBufferFunc)(void* self, UINT index, const void* riid, void** out);
    typedef HRESULT (__stdcall *SwapPresentFunc)(void* self, UINT syncInterval, UINT flags);

    typedef HRESULT (__stdcall *DCompCreateTargetForHwndFunc)(void* self, void* hwnd, int topmost, void** out);
    typedef HRESULT (__stdcall *DCompCreateVisualFunc)(void* self, void** out);
    typedef HRESULT (__stdcall *DCompCommitFunc)(void* self);

    typedef HRESULT (__stdcall *DCompSetRootFunc)(void* self, void* root);
    typedef HRESULT (__stdcall *DCompVisualSetContentFunc)(void* self, void* content);
    typedef HRESULT (__stdcall *DCompVisualSetOffsetXFunc)(void* self, float x);
    typedef HRESULT (__stdcall *DCompVisualSetOffsetYFunc)(void* self, float y);
    typedef HRESULT (__stdcall *DCompVisualAddVisualFunc)(void* self, void* visual, int insertAbove, void* reference);

    typedef HRESULT (__stdcall *CreateRenderTargetViewFunc)(void* self, void* resource, void* desc, void** out);
    typedef HRESULT (__stdcall *CreateTexture2DFunc)(void* self, const void* desc, const void* initData, void** out);

    typedef void (__stdcall *ContextClearRenderTargetViewFunc)(void* self, void* rtv, const float* color);
    typedef void (__stdcall *ContextOMSetRenderTargetsFunc)(void* self, UINT count, void** rtvs, void* dsv);
    typedef void (__stdcall *ContextRSSetViewportsFunc)(void* self, UINT count, const void* vp);
    typedef void (__stdcall *ContextIASetInputLayoutFunc)(void* self, void* layout);
    typedef void (__stdcall *ContextIASetPrimitiveTopologyFunc)(void* self, UINT topology);
    typedef void (__stdcall *ContextVSSetShaderFunc)(void* self, void* vs, void* classInst, UINT classCount);
    typedef void (__stdcall *ContextPSSetShaderFunc)(void* self, void* ps, void* classInst, UINT classCount);
    typedef void (__stdcall *ContextDrawFunc)(void* self, UINT vertexCount, UINT startVertex);
    typedef void (__stdcall *ContextCopyResourceFunc)(void* self, void* dst, void* src);
    typedef HRESULT (__stdcall *ContextMapFunc)(void* self, void* resource, UINT subresource, UINT mapType, UINT mapFlags, void* mappedSubresource);
    typedef void (__stdcall *ContextUnmapFunc)(void* self, void* resource, UINT subresource);

    typedef HRESULT (__stdcall *CreateVertexShaderFunc)(void* self, const void* bytecode, SIZE_T bytecodeLen, void* linkage, void** out);
    typedef HRESULT (__stdcall *CreatePixelShaderFunc)(void* self, const void* bytecode, SIZE_T bytecodeLen, void* linkage, void** out);

    typedef void* (__stdcall *BlobGetPtrFunc)(void* self);
    typedef SIZE_T (__stdcall *BlobGetSizeFunc)(void* self);

    typedef struct DXGI_SAMPLE_DESC { UINT Count; UINT Quality; } DXGI_SAMPLE_DESC;

    typedef struct DXGI_SWAP_CHAIN_DESC1 {
        UINT             Width;
        UINT             Height;
        UINT             Format;
        UINT             Stereo;
        DXGI_SAMPLE_DESC SampleDesc;
        UINT             BufferUsage;
        UINT             BufferCount;
        UINT             Scaling;
        UINT             SwapEffect;
        UINT             AlphaMode;
        UINT             Flags;
    } DXGI_SWAP_CHAIN_DESC1;

    typedef struct D3D11_TEXTURE2D_DESC {
        UINT             Width;
        UINT             Height;
        UINT             MipLevels;
        UINT             ArraySize;
        UINT             Format;
        DXGI_SAMPLE_DESC SampleDesc;
        UINT             Usage;
        UINT             BindFlags;
        UINT             CPUAccessFlags;
        UINT             MiscFlags;
    } D3D11_TEXTURE2D_DESC;

    typedef struct D3D11_MAPPED_SUBRESOURCE {
        void* pData;
        UINT RowPitch;
        UINT DepthPitch;
    } D3D11_MAPPED_SUBRESOURCE;

    typedef struct D3D11_VIEWPORT {
        float TopLeftX;
        float TopLeftY;
        float Width;
        float Height;
        float MinDepth;
        float MaxDepth;
    } D3D11_VIEWPORT;

    typedef HRESULT (__stdcall *D3D11CreateDeviceFunc)(
        void* pAdapter,
        UINT DriverType,
        void* Software,
        UINT Flags,
        const UINT* pFeatureLevels,
        UINT FeatureLevels,
        UINT SDKVersion,
        void** ppDevice,
        UINT* pFeatureLevel,
        void** ppImmediateContext
    );

    typedef HRESULT (__stdcall *DCompositionCreateDeviceFunc)(void* renderingDevice, const void* iid, void** out);

    typedef HRESULT (__stdcall *D3DCompileFunc)(
        const void* srcData,
        SIZE_T srcLen,
        const char* sourceName,
        const void* defines,
        const void* include,
        const char* entry,
        const char* target,
        UINT flags1,
        UINT flags2,
        void** outCode,
        void** outErr
    );

    typedef void* HGLRC;
    typedef void* HDC;
    typedef HGLRC (*wglCreateContextAttribsARBProc)(HDC hdc, HGLRC share, const int* attribs);
    typedef int (*wglDXCloseDeviceNVProc)(void* dev);
    typedef void* (*wglDXOpenDeviceNVProc)(void* dxDev);
    typedef void* (*wglDXRegisterObjectNVProc)(void* dev, void* dxObj, unsigned int name, unsigned int type, unsigned int access);
    typedef int (*wglDXUnregisterObjectNVProc)(void* dev, void* obj);
    typedef int (*wglDXLockObjectsNVProc)(void* dev, int count, void** objs);
    typedef int (*wglDXUnlockObjectsNVProc)(void* dev, int count, void** objs);

    typedef unsigned int GLuint;
    typedef int GLint;
    typedef unsigned int GLenum;
    typedef int GLsizei;
    typedef unsigned char GLboolean;
    typedef long long GLsizeiptr;
    typedef char GLchar;

    typedef GLuint (*glCreateShaderProc)(GLenum type);
    typedef void (*glShaderSourceProc)(GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
    typedef void (*glCompileShaderProc)(GLuint shader);
    typedef void (*glGetShaderivProc)(GLuint shader, GLenum pname, GLint* params);
    typedef void (*glGetShaderInfoLogProc)(GLuint shader, GLsizei maxLen, GLsizei* outLen, GLchar* log);
    typedef GLuint (*glCreateProgramProc)(void);
    typedef void (*glAttachShaderProc)(GLuint program, GLuint shader);
    typedef void (*glLinkProgramProc)(GLuint program);
    typedef void (*glGetProgramivProc)(GLuint program, GLenum pname, GLint* params);
    typedef void (*glGetProgramInfoLogProc)(GLuint program, GLsizei maxLen, GLsizei* outLen, GLchar* log);
    typedef void (*glUseProgramProc)(GLuint program);
    typedef void (*glGenVertexArraysProc)(GLsizei n, GLuint* arrays);
    typedef void (*glBindVertexArrayProc)(GLuint array);
    typedef void (*glGenBuffersProc)(GLsizei n, GLuint* buffers);
    typedef void (*glBindBufferProc)(GLenum target, GLuint buffer);
    typedef void (*glBufferDataProc)(GLenum target, GLsizeiptr size, const void* data, GLenum usage);
    typedef void (*glVertexAttribPointerProc)(GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void* pointer);
    typedef void (*glEnableVertexAttribArrayProc)(GLuint index);
    typedef void (*glDrawArraysProc)(GLenum mode, GLint first, GLsizei count);
    typedef void (*glGenRenderbuffersProc)(GLsizei n, GLuint* renderbuffers);
    typedef void (*glBindRenderbufferProc)(GLenum target, GLuint renderbuffer);
    typedef void (*glGenFramebuffersProc)(GLsizei n, GLuint* framebuffers);
    typedef void (*glBindFramebufferProc)(GLenum target, GLuint framebuffer);
    typedef void (*glFramebufferRenderbufferProc)(GLenum target, GLenum attachment, GLenum renderbuffertarget, GLuint renderbuffer);
');

$d3d11dll = $kernel32->LoadLibraryW(FFI::addr(wbuf('d3d11.dll')[0]));
$dcompdll = $kernel32->LoadLibraryW(FFI::addr(wbuf('dcomp.dll')[0]));
$d3dcompilerdll = $kernel32->LoadLibraryW(FFI::addr(wbuf('d3dcompiler_47.dll')[0]));

if ($d3d11dll === null || $dcompdll === null || $d3dcompilerdll === null) {
    throw new RuntimeException('Failed to load required DLLs');
}
log_msg('DLLs loaded: d3d11, dcomp, d3dcompiler_47', $kernel32);

$D3D11CreateDevice = $types->cast('D3D11CreateDeviceFunc', $kernel32->GetProcAddress($d3d11dll, FFI::addr(abuf('D3D11CreateDevice')[0])));
$DCompositionCreateDevice = $types->cast('DCompositionCreateDeviceFunc', $kernel32->GetProcAddress($dcompdll, FFI::addr(abuf('DCompositionCreateDevice')[0])));
$D3DCompile = $types->cast('D3DCompileFunc', $kernel32->GetProcAddress($d3dcompilerdll, FFI::addr(abuf('D3DCompile')[0])));

if (FFI::isNull($D3D11CreateDevice) || FFI::isNull($DCompositionCreateDevice) || FFI::isNull($D3DCompile)) {
    throw new RuntimeException('Failed to resolve D3D entry points');
}
log_msg('D3D/DComp entry points resolved', $kernel32);

$wndProc = $kernel32->GetProcAddress($kernel32->LoadLibraryW(FFI::addr(wbuf('user32.dll')[0])), FFI::addr(abuf('DefWindowProcA')[0]));
if ($wndProc === null) {
    throw new RuntimeException('GetProcAddress(DefWindowProcA) failed');
}

$hInstance = $kernel32->GetModuleHandleW(null);
$className = abuf('PhpDCompMulti');
$windowName = abuf('OpenGL + D3D11 + Vulkan (DirectComposition / PHP)');

// WNDCLASSEXA is defined in the $user32 FFI context, not $types.
$wcex = $user32->new('WNDCLASSEXA');
$wcex->cbSize = FFI::sizeof($wcex);
$wcex->style = CS_OWNDC;
$wcex->lpfnWndProc = $wndProc;
$wcex->cbClsExtra = 0;
$wcex->cbWndExtra = 0;
$wcex->hInstance = $hInstance;
$wcex->hIcon = null;
$wcex->hCursor = null;
$wcex->hbrBackground = null;
$wcex->lpszMenuName = null;
$wcex->lpszClassName = $basicTypes->cast('char*', FFI::addr($className[0]));
$wcex->hIconSm = null;

$atom = $user32->RegisterClassExA(FFI::addr($wcex));
if ($atom === 0) {
    throw new RuntimeException('RegisterClassExA failed: ' . (string)$kernel32->GetLastError());
}
log_msg("RegisterClassExA atom=$atom", $kernel32);

// Pass PHP strings directly — FFI auto-converts them to const char* (LPCSTR).
log_msg('Calling CreateWindowExA...', $kernel32);
$hwnd = $user32->CreateWindowExA(
    0,
    'PhpDCompMulti',
    'OpenGL + D3D11 + Vulkan (DirectComposition / PHP)',
    WS_OVERLAPPEDWINDOW,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    WINDOW_W,
    WINDOW_H,
    null,
    null,
    $hInstance,
    null
);
if ($hwnd === null) {
    throw new RuntimeException('CreateWindowExA failed: err=' . (string)$kernel32->GetLastError());
}
log_msg('CreateWindowExA returned non-null hwnd', $kernel32);
$user32->ShowWindow($hwnd, SW_SHOW);
log_msg('ShowWindow done', $kernel32);
$user32->UpdateWindow($hwnd);
log_msg('UpdateWindow done — window ready', $kernel32);

log_msg('Calling D3D11CreateDevice...', $kernel32);
$featureLevels = ffi_new('unsigned int[1]', false);
$featureLevels[0] = D3D_FEATURE_LEVEL_11_0;
$ppDevice = ffi_new('void*[1]', false);
$ppCtx = ffi_new('void*[1]', false);
$hr = $D3D11CreateDevice(
    null,
    D3D_DRIVER_TYPE_HARDWARE,
    null,
    D3D11_CREATE_DEVICE_BGRA_SUPPORT,
    FFI::addr($featureLevels[0]),
    1,
    D3D11_SDK_VERSION,
    FFI::addr($ppDevice[0]),
    null,
    FFI::addr($ppCtx[0])
);
if ($hr < 0) {
    throw new RuntimeException(sprintf('D3D11CreateDevice failed: 0x%08X', $hr & 0xFFFFFFFF));
}
$device = $ppDevice[0];
$ctx = $ppCtx[0];
log_msg('D3D11 device created', $kernel32);

$iidDxgiDevice = guid_from_string('54EC77FA-1377-44E6-8C32-88FD5F44C84C');
$ppDxgiDevice = ffi_new('void*[1]', false);
$qi = com_fn($device, 0, 'QueryInterfaceFunc');
$hr = $qi($device, FFI::addr($iidDxgiDevice[0]), FFI::addr($ppDxgiDevice[0]));
if ($hr < 0) {
    throw new RuntimeException(sprintf('QI IDXGIDevice failed: 0x%08X', $hr & 0xFFFFFFFF));
}
$dxgiDevice = $ppDxgiDevice[0];
log_msg('QI IDXGIDevice ok', $kernel32);

$iidDCompDevice = guid_from_string('C37EA93A-E7AA-450D-B16F-9746CB0407F3');
$ppDComp = ffi_new('void*[1]', false);
$hr = $DCompositionCreateDevice($dxgiDevice, FFI::addr($iidDCompDevice[0]), FFI::addr($ppDComp[0]));
com_release($dxgiDevice);
if ($hr < 0) {
    throw new RuntimeException(sprintf('DCompositionCreateDevice failed: 0x%08X', $hr & 0xFFFFFFFF));
}
$dcompDevice = $ppDComp[0];
log_msg('DCompositionCreateDevice ok', $kernel32);

$createTargetForHwnd = com_fn($dcompDevice, 6, 'DCompCreateTargetForHwndFunc');
$ppDCompTarget = ffi_new('void*[1]', false);
$hr = $createTargetForHwnd($dcompDevice, $hwnd, 1, FFI::addr($ppDCompTarget[0]));
if ($hr < 0) {
    throw new RuntimeException('CreateTargetForHwnd failed');
}
$dcompTarget = $ppDCompTarget[0];
log_msg('CreateTargetForHwnd ok', $kernel32);

$createVisual = com_fn($dcompDevice, 7, 'DCompCreateVisualFunc');
$ppRootVisual = ffi_new('void*[1]', false);
$hr = $createVisual($dcompDevice, FFI::addr($ppRootVisual[0]));
if ($hr < 0) {
    throw new RuntimeException('CreateVisual(root) failed');
}
$rootVisual = $ppRootVisual[0];

$setRoot = com_fn($dcompTarget, 3, 'DCompSetRootFunc');
$setRoot($dcompTarget, $rootVisual);
log_msg('DirectComposition initialized', $kernel32);

$iidFactory2 = guid_from_string('50C83A1C-E072-4C48-87B0-3630FA36A6D0');
$iidTex2D = guid_from_string('6F15AAF2-D208-4E89-9AB4-489535D34F9C');

$createSwapchain = function (int $width, int $height) use ($device, $qi, $iidDxgiDevice, $iidFactory2, $types, $kernel32): FFI\CData {
    $ppDxgiDevice = ffi_new('void*[1]', false);
    $hr = $qi($device, FFI::addr($iidDxgiDevice[0]), FFI::addr($ppDxgiDevice[0]));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('QI IDXGIDevice failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    $dxgiDevice = $ppDxgiDevice[0];

    $getAdapter = com_fn($dxgiDevice, 7, 'GetAdapterFunc');
    $ppAdapter = ffi_new('void*[1]', false);
    $hr = $getAdapter($dxgiDevice, FFI::addr($ppAdapter[0]));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('GetAdapter failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    $adapter = $ppAdapter[0];

    $getParent = com_fn($adapter, 6, 'GetParentFunc');
    $ppFactory = ffi_new('void*[1]', false);
    $hr = $getParent($adapter, FFI::addr($iidFactory2[0]), FFI::addr($ppFactory[0]));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('GetParent(IDXGIFactory2) failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    $factory = $ppFactory[0];

    $alphaModes = [DXGI_ALPHA_MODE_PREMULTIPLIED, DXGI_ALPHA_MODE_IGNORE];
    $created = null;
    $lastHr = 0;

    foreach ($alphaModes as $alpha) {
        $desc = $types->new('DXGI_SWAP_CHAIN_DESC1');
        FFI::memset(FFI::addr($desc), 0, FFI::sizeof($desc));
        $desc->Width = $width;
        $desc->Height = $height;
        $desc->Format = DXGI_FORMAT_B8G8R8A8_UNORM;
        $desc->Stereo = 0;
        $desc->SampleDesc->Count = 1;
        $desc->SampleDesc->Quality = 0;
        $desc->BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        $desc->BufferCount = 2;
        $desc->Scaling = DXGI_SCALING_STRETCH;
        $desc->SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
        $desc->AlphaMode = $alpha;

        $ppSc = ffi_new('void*[1]', false);
        $fn = com_fn($factory, 24, 'CreateSwapChainForCompositionFunc');
        $hr = $fn($factory, $device, FFI::addr($desc), null, FFI::addr($ppSc[0]));
        $lastHr = $hr;
        if ($hr >= 0) {
            $created = $ppSc[0];
            log_msg("CreateSwapChainForComposition succeeded (alpha=$alpha)", $kernel32);
            break;
        }
        log_msg(sprintf('CreateSwapChainForComposition failed (alpha=%d): 0x%08X', $alpha, $hr & 0xFFFFFFFF), $kernel32);
    }

    com_release($factory);
    com_release($adapter);
    com_release($dxgiDevice);

    if ($created === null) {
        throw new RuntimeException(sprintf('CreateSwapChainForComposition failed after retries: 0x%08X', $lastHr & 0xFFFFFFFF));
    }
    return $created;
};

$swapchainGetBuffer = function (FFI\CData $sc) use ($iidTex2D): FFI\CData {
    $fn = com_fn($sc, 9, 'SwapGetBufferFunc');
    $ppTex = ffi_new('void*[1]', false);
    $hr = $fn($sc, 0, FFI::addr($iidTex2D[0]), FFI::addr($ppTex[0]));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('SwapChain GetBuffer failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    return $ppTex[0];
};

$swapchainPresent = function (FFI\CData $sc): int {
    $fn = com_fn($sc, 8, 'SwapPresentFunc');
    return (int)$fn($sc, 1, 0);
};

$createRTV = function (FFI\CData $tex) use ($device): FFI\CData {
    $fn = com_fn($device, 9, 'CreateRenderTargetViewFunc');
    $ppRTV = ffi_new('void*[1]', false);
    $hr = $fn($device, $tex, null, FFI::addr($ppRTV[0]));
    if ($hr < 0) {
        throw new RuntimeException('CreateRenderTargetView failed');
    }
    return $ppRTV[0];
};

// D3D11 context vtable indices used below:
//   5  = CreateTexture2D
//  14  = Map
//  15  = Unmap
//  47  = CopyResource

$createStagingTexture = function (int $width, int $height) use ($device, $types, $kernel32): FFI\CData {
    $desc = $types->new('D3D11_TEXTURE2D_DESC');
    FFI::memset(FFI::addr($desc), 0, FFI::sizeof($desc));
    $desc->Width = $width;
    $desc->Height = $height;
    $desc->MipLevels = 1;
    $desc->ArraySize = 1;
    $desc->Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    $desc->SampleDesc->Count = 1;
    $desc->SampleDesc->Quality = 0;
    $desc->Usage = D3D11_USAGE_STAGING;
    $desc->BindFlags = 0;
    $desc->CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    $desc->MiscFlags = 0;
    $ppTex = ffi_new('void*[1]', false);
    $fn = com_fn($device, 5, 'CreateTexture2DFunc');
    $hr = $fn($device, FFI::addr($desc), null, FFI::addr($ppTex[0]));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('CreateTexture2D(staging) failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    log_msg('Staging texture created', $kernel32);
    return $ppTex[0];
};

$ctxMap = function (FFI\CData $resource) use ($ctx, $types): FFI\CData {
    $mapped = $types->new('D3D11_MAPPED_SUBRESOURCE');
    FFI::memset(FFI::addr($mapped), 0, FFI::sizeof($mapped));
    $fn = com_fn($ctx, 14, 'ContextMapFunc');
    $hr = $fn($ctx, $resource, 0, D3D11_MAP_WRITE, 0, FFI::addr($mapped));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('D3D11 Map failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    return $mapped;
};

$ctxUnmap = function (FFI\CData $resource) use ($ctx): void {
    $fn = com_fn($ctx, 15, 'ContextUnmapFunc');
    $fn($ctx, $resource, 0);
};

$ctxCopyResource = function (FFI\CData $dst, FFI\CData $src) use ($ctx): void {
    $fn = com_fn($ctx, 47, 'ContextCopyResourceFunc');
    $fn($ctx, $dst, $src);
};

$createPanelVisual = function (FFI\CData $sc, float $offsetX) use ($dcompDevice, $rootVisual): FFI\CData {
    $createVisual = com_fn($dcompDevice, 7, 'DCompCreateVisualFunc');
    $ppVis = ffi_new('void*[1]', false);
    $hr = $createVisual($dcompDevice, FFI::addr($ppVis[0]));
    if ($hr < 0) {
        throw new RuntimeException('CreateVisual(panel) failed');
    }
    $vis = $ppVis[0];

    $setContent = com_fn($vis, 15, 'DCompVisualSetContentFunc');
    $setOffsetX = com_fn($vis, 4, 'DCompVisualSetOffsetXFunc');
    $setOffsetY = com_fn($vis, 6, 'DCompVisualSetOffsetYFunc');
    $addVisual = com_fn($rootVisual, 16, 'DCompVisualAddVisualFunc');

    $setContent($vis, $sc);
    $setOffsetX($vis, $offsetX);
    $setOffsetY($vis, 0.0);
    $addVisual($rootVisual, $vis, 1, null);

    return $vis;
};

$createPanel = function (float $offsetX) use ($createSwapchain, $swapchainGetBuffer, $createRTV, $createPanelVisual): array {
    $sc = $createSwapchain(PANEL_W, PANEL_H);
    $bb = $swapchainGetBuffer($sc);
    $rtv = $createRTV($bb);
    $vis = $createPanelVisual($sc, $offsetX);
    return ['sc' => $sc, 'bb' => $bb, 'rtv' => $rtv, 'vis' => $vis];
};

log_msg('Creating GL panel (offset=0)...', $kernel32);
$glPanel = $createPanel(0.0);
log_msg('GL panel created', $kernel32);
log_msg(sprintf('Creating DX panel (offset=%d)...', PANEL_W), $kernel32);
$dxPanel = $createPanel((float)PANEL_W);
log_msg('DX panel created', $kernel32);
log_msg(sprintf('Creating VK panel (offset=%d)...', PANEL_W * 2), $kernel32);
$vkPanel = $createPanel((float)(PANEL_W * 2));
log_msg('VK panel created', $kernel32);
$glPanel['name'] = 'OpenGL panel';
$dxPanel['name'] = 'DirectX panel';
$vkPanel['name'] = 'Vulkan panel';

$compileHlsl = function (string $src, string $entry, string $target) use ($D3DCompile): FFI\CData {
    $ppCode = ffi_new('void*[1]', false);
    $ppErr = ffi_new('void*[1]', false);
    $srcBuf = cstr($src);
    $hr = $D3DCompile(
        FFI::addr($srcBuf[0]),
        strlen($src),
        'inline.hlsl',
        null,
        null,
        $entry,
        $target,
        0,
        0,
        FFI::addr($ppCode[0]),
        FFI::addr($ppErr[0])
    );
    if ($hr < 0) {
        if ($ppErr[0] !== null) {
            $msg = read_blob_string($ppErr[0]);
            com_release($ppErr[0]);
            throw new RuntimeException("D3DCompile $entry/$target failed: $msg");
        }
        throw new RuntimeException(sprintf('D3DCompile %s/%s failed: 0x%08X', $entry, $target, $hr & 0xFFFFFFFF));
    }
    return $ppCode[0];
};

$initD3D11TrianglePipeline = function (array &$panel) use ($device, $compileHlsl, $types, $kernel32): void {
    log_msg('Init D3D11 triangle pipeline start', $kernel32);

    $hlsl = <<<'HLSL'
struct PSIn {
  float4 pos : SV_POSITION;
  float4 col : COLOR;
};

PSIn VS(uint vid : SV_VertexID)
{
  float2 p[3] = {
    float2( 0.0,  0.5),
    float2( 0.5, -0.5),
    float2(-0.5, -0.5)
  };
  float4 c[3] = {
    float4(1,0,0,1),
    float4(0,1,0,1),
    float4(0,0,1,1)
  };
  PSIn o;
  o.pos = float4(p[vid], 0.0, 1.0);
  o.col = c[vid];
  return o;
}

float4 PS(PSIn i) : SV_Target
{
  return i.col;
}
HLSL;

    $vsBlob = $compileHlsl($hlsl, 'VS', 'vs_4_0');
    $psBlob = $compileHlsl($hlsl, 'PS', 'ps_4_0');

    $vsPtrFn = com_fn($vsBlob, 3, 'BlobGetPtrFunc');
    $vsSizeFn = com_fn($vsBlob, 4, 'BlobGetSizeFunc');
    $psPtrFn = com_fn($psBlob, 3, 'BlobGetPtrFunc');
    $psSizeFn = com_fn($psBlob, 4, 'BlobGetSizeFunc');

    $vsPtr = $vsPtrFn($vsBlob);
    $vsSize = (int)$vsSizeFn($vsBlob);
    $psPtr = $psPtrFn($psBlob);
    $psSize = (int)$psSizeFn($psBlob);

    $createVS = com_fn($device, 12, 'CreateVertexShaderFunc');
    $createPS = com_fn($device, 15, 'CreatePixelShaderFunc');

    $ppVS = ffi_new('void*[1]', false);
    $hr = $createVS($device, $vsPtr, $vsSize, null, FFI::addr($ppVS[0]));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('CreateVertexShader failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    $panel['vs'] = $ppVS[0];

    $ppPS = ffi_new('void*[1]', false);
    $hr = $createPS($device, $psPtr, $psSize, null, FFI::addr($ppPS[0]));
    if ($hr < 0) {
        throw new RuntimeException(sprintf('CreatePixelShader failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    $panel['ps'] = $ppPS[0];

    $rtvArr = ffi_new('void*[1]', false);
    $rtvArr[0] = $panel['rtv'];
    $panel['rtv_arr'] = $rtvArr;

    $vp = $types->new('D3D11_VIEWPORT');
    $vp->TopLeftX = 0.0;
    $vp->TopLeftY = 0.0;
    $vp->Width = (float)PANEL_W;
    $vp->Height = (float)PANEL_H;
    $vp->MinDepth = 0.0;
    $vp->MaxDepth = 1.0;
    $panel['vp'] = $vp;

    com_release($vsBlob);
    com_release($psBlob);
    log_msg('Init D3D11 triangle pipeline done', $kernel32);
};

$clearRTV = function (FFI\CData $rtv, float $r, float $g, float $b, float $a) use ($ctx): void {
    $color = ffi_new('float[4]', false);
    $color[0] = $r;
    $color[1] = $g;
    $color[2] = $b;
    $color[3] = $a;
    $fn = com_fn($ctx, 50, 'ContextClearRenderTargetViewFunc');
    $fn($ctx, $rtv, FFI::addr($color[0]));
};

$renderTrianglePanel = function (array &$panel, array $bg) use ($ctx, $clearRTV, $swapchainPresent, $kernel32): bool {
    $clearRTV($panel['rtv'], $bg[0], $bg[1], $bg[2], 1.0);

    com_fn($ctx, 33, 'ContextOMSetRenderTargetsFunc')($ctx, 1, FFI::addr($panel['rtv_arr'][0]), null);
    com_fn($ctx, 44, 'ContextRSSetViewportsFunc')($ctx, 1, FFI::addr($panel['vp']));
    com_fn($ctx, 17, 'ContextIASetInputLayoutFunc')($ctx, null);
    com_fn($ctx, 24, 'ContextIASetPrimitiveTopologyFunc')($ctx, 4);
    com_fn($ctx, 11, 'ContextVSSetShaderFunc')($ctx, $panel['vs'], null, 0);
    com_fn($ctx, 9, 'ContextPSSetShaderFunc')($ctx, $panel['ps'], null, 0);
    com_fn($ctx, 13, 'ContextDrawFunc')($ctx, 3, 0);

    $hr = $swapchainPresent($panel['sc']);
    if ($hr < 0) {
        log_msg(sprintf('Triangle panel Present failed: 0x%08X', $hr & 0xFFFFFFFF), $kernel32);
        return false;
    }
    if (!isset($panel['first_present_logged'])) {
        log_msg($panel['name'] . ' first present succeeded', $kernel32);
        $panel['first_present_logged'] = true;
    }
    return true;
};

$glNative = false;
try {
    log_msg('Init OpenGL interop panel start', $kernel32);
    $hdc = $user32->GetDC($hwnd);
    if ($hdc === null) {
        throw new RuntimeException('GetDC failed for OpenGL panel');
    }

    $pfd = $gdi32->new('PIXELFORMATDESCRIPTOR');
    FFI::memset(FFI::addr($pfd), 0, FFI::sizeof($pfd));
    $pfd->nSize = FFI::sizeof($pfd);
    $pfd->nVersion = 1;
    $pfd->dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    $pfd->iPixelType = PFD_TYPE_RGBA;
    $pfd->cColorBits = 32;
    $pfd->cDepthBits = 24;
    $pfd->iLayerType = PFD_MAIN_PLANE;

    $pf = $gdi32->ChoosePixelFormat($hdc, FFI::addr($pfd));
    if ($pf === 0) {
        throw new RuntimeException('ChoosePixelFormat failed');
    }
    if (!$gdi32->SetPixelFormat($hdc, $pf, FFI::addr($pfd))) {
        throw new RuntimeException('SetPixelFormat failed');
    }

    $hrcOld = $opengl32->wglCreateContext($hdc);
    if (FFI::isNull($hrcOld)) {
        throw new RuntimeException('wglCreateContext failed');
    }
    if (!$opengl32->wglMakeCurrent($hdc, $hrcOld)) {
        throw new RuntimeException('wglMakeCurrent failed');
    }

    $getGL = function (string $name, string $type) use ($opengl32, $types): FFI\CData {
        $addr = $opengl32->wglGetProcAddress($name);
        if (FFI::isNull($addr)) {
            throw new RuntimeException("wglGetProcAddress failed: $name");
        }
        return $types->cast($type, $addr);
    };

    $wglCreateContextAttribsARB = $getGL('wglCreateContextAttribsARB', 'wglCreateContextAttribsARBProc');
    $attribs = $basicTypes->new('int[7]', false);
    $attribs[0] = WGL_CONTEXT_MAJOR_VERSION_ARB;
    $attribs[1] = 4;
    $attribs[2] = WGL_CONTEXT_MINOR_VERSION_ARB;
    $attribs[3] = 6;
    $attribs[4] = WGL_CONTEXT_PROFILE_MASK_ARB;
    $attribs[5] = WGL_CONTEXT_CORE_PROFILE_BIT_ARB;
    $attribs[6] = 0;

    $hrc = $wglCreateContextAttribsARB($hdc, null, FFI::addr($attribs[0]));
    if (FFI::isNull($hrc)) {
        throw new RuntimeException('wglCreateContextAttribsARB failed');
    }
    if (!$opengl32->wglMakeCurrent($hdc, $hrc)) {
        throw new RuntimeException('wglMakeCurrent(GL4.6) failed');
    }
    $opengl32->wglDeleteContext($hrcOld);

    // glGetString returns const char* — PHP FFI converts this to a PHP string directly.
    $ver = $opengl32->glGetString(GL_VERSION);
    $slv = $opengl32->glGetString(GL_SHADING_LANGUAGE_VERSION);
    if ($ver !== null) {
        log_msg('OpenGL VERSION=' . $ver, $kernel32);
    }
    if ($slv !== null) {
        log_msg('GLSL VERSION=' . $slv, $kernel32);
    }

    $gl = [
        'wglDXOpenDeviceNV' => $getGL('wglDXOpenDeviceNV', 'wglDXOpenDeviceNVProc'),
        'wglDXCloseDeviceNV' => $getGL('wglDXCloseDeviceNV', 'wglDXCloseDeviceNVProc'),
        'wglDXRegisterObjectNV' => $getGL('wglDXRegisterObjectNV', 'wglDXRegisterObjectNVProc'),
        'wglDXUnregisterObjectNV' => $getGL('wglDXUnregisterObjectNV', 'wglDXUnregisterObjectNVProc'),
        'wglDXLockObjectsNV' => $getGL('wglDXLockObjectsNV', 'wglDXLockObjectsNVProc'),
        'wglDXUnlockObjectsNV' => $getGL('wglDXUnlockObjectsNV', 'wglDXUnlockObjectsNVProc'),
        'glGenRenderbuffers' => $getGL('glGenRenderbuffers', 'glGenRenderbuffersProc'),
        'glBindRenderbuffer' => $getGL('glBindRenderbuffer', 'glBindRenderbufferProc'),
        'glGenFramebuffers' => $getGL('glGenFramebuffers', 'glGenFramebuffersProc'),
        'glBindFramebuffer' => $getGL('glBindFramebuffer', 'glBindFramebufferProc'),
        'glFramebufferRenderbuffer' => $getGL('glFramebufferRenderbuffer', 'glFramebufferRenderbufferProc'),
        'glCreateShader' => $getGL('glCreateShader', 'glCreateShaderProc'),
        'glShaderSource' => $getGL('glShaderSource', 'glShaderSourceProc'),
        'glCompileShader' => $getGL('glCompileShader', 'glCompileShaderProc'),
        'glGetShaderiv' => $getGL('glGetShaderiv', 'glGetShaderivProc'),
        'glGetShaderInfoLog' => $getGL('glGetShaderInfoLog', 'glGetShaderInfoLogProc'),
        'glCreateProgram' => $getGL('glCreateProgram', 'glCreateProgramProc'),
        'glAttachShader' => $getGL('glAttachShader', 'glAttachShaderProc'),
        'glLinkProgram' => $getGL('glLinkProgram', 'glLinkProgramProc'),
        'glGetProgramiv' => $getGL('glGetProgramiv', 'glGetProgramivProc'),
        'glGetProgramInfoLog' => $getGL('glGetProgramInfoLog', 'glGetProgramInfoLogProc'),
        'glUseProgram' => $getGL('glUseProgram', 'glUseProgramProc'),
        'glGenVertexArrays' => $getGL('glGenVertexArrays', 'glGenVertexArraysProc'),
        'glBindVertexArray' => $getGL('glBindVertexArray', 'glBindVertexArrayProc'),
        'glGenBuffers' => $getGL('glGenBuffers', 'glGenBuffersProc'),
        'glBindBuffer' => $getGL('glBindBuffer', 'glBindBufferProc'),
        'glBufferData' => $getGL('glBufferData', 'glBufferDataProc'),
        'glVertexAttribPointer' => $getGL('glVertexAttribPointer', 'glVertexAttribPointerProc'),
        'glEnableVertexAttribArray' => $getGL('glEnableVertexAttribArray', 'glEnableVertexAttribArrayProc'),
        'glDrawArrays' => $getGL('glDrawArrays', 'glDrawArraysProc'),
    ];

    $interopDev = $gl['wglDXOpenDeviceNV']($device);
    if (FFI::isNull($interopDev)) {
        throw new RuntimeException('wglDXOpenDeviceNV failed');
    }

    $rbo = ffi_new('unsigned int[1]', false);
    $gl['glGenRenderbuffers'](1, FFI::addr($rbo[0]));
    if ((int)$rbo[0] === 0) {
        throw new RuntimeException('glGenRenderbuffers failed');
    }
    $gl['glBindRenderbuffer'](GL_RENDERBUFFER, $rbo[0]);

    $interopObj = $gl['wglDXRegisterObjectNV']($interopDev, $glPanel['bb'], $rbo[0], GL_RENDERBUFFER, WGL_ACCESS_READ_WRITE_NV);
    if (FFI::isNull($interopObj)) {
        throw new RuntimeException('wglDXRegisterObjectNV failed');
    }

    $fbo = ffi_new('unsigned int[1]', false);
    $gl['glGenFramebuffers'](1, FFI::addr($fbo[0]));
    if ((int)$fbo[0] === 0) {
        throw new RuntimeException('glGenFramebuffers failed');
    }
    $gl['glBindFramebuffer'](GL_FRAMEBUFFER, $fbo[0]);
    $gl['glFramebufferRenderbuffer'](GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, $rbo[0]);
    $gl['glBindFramebuffer'](GL_FRAMEBUFFER, 0);

    $compileShader = function (int $type, string $src) use ($gl, $types, $basicTypes): int {
        $shader = (int)$gl['glCreateShader']($type);
        $srcBuf = cstr($src);
        $srcPtr = $basicTypes->new('char*[1]', false);
        $srcPtr[0] = $types->cast('char*', FFI::addr($srcBuf[0]));
        $len = $basicTypes->new('int[1]', false);
        $len[0] = strlen($src);
        $gl['glShaderSource']($shader, 1, FFI::addr($srcPtr[0]), FFI::addr($len[0]));
        $gl['glCompileShader']($shader);
        $status = $basicTypes->new('int[1]', false);
        $gl['glGetShaderiv']($shader, GL_COMPILE_STATUS, FFI::addr($status[0]));
        if ((int)$status[0] !== 1) {
            $logLen = ffi_new('int[1]', false);
            $gl['glGetShaderiv']($shader, GL_INFO_LOG_LENGTH, FFI::addr($logLen[0]));
            if ((int)$logLen[0] > 1) {
                $buf = ffi_new('char[' . (int)$logLen[0] . ']', false);
                $outLen = ffi_new('int[1]', false);
                $gl['glGetShaderInfoLog']($shader, (int)$logLen[0], FFI::addr($outLen[0]), FFI::addr($buf[0]));
                throw new RuntimeException('OpenGL shader compile failed: ' . FFI::string($buf));
            }
            throw new RuntimeException('OpenGL shader compile failed');
        }
        return $shader;
    };

    $linkProgram = function (int $vs, int $fs) use ($gl): int {
        $prog = (int)$gl['glCreateProgram']();
        $gl['glAttachShader']($prog, $vs);
        $gl['glAttachShader']($prog, $fs);
        $gl['glLinkProgram']($prog);
        $status = ffi_new('int[1]', false);
        $gl['glGetProgramiv']($prog, GL_LINK_STATUS, FFI::addr($status[0]));
        if ((int)$status[0] !== 1) {
            $logLen = ffi_new('int[1]', false);
            $gl['glGetProgramiv']($prog, GL_INFO_LOG_LENGTH, FFI::addr($logLen[0]));
            if ((int)$logLen[0] > 1) {
                $buf = ffi_new('char[' . (int)$logLen[0] . ']', false);
                $outLen = ffi_new('int[1]', false);
                $gl['glGetProgramInfoLog']($prog, (int)$logLen[0], FFI::addr($outLen[0]), FFI::addr($buf[0]));
                throw new RuntimeException('OpenGL program link failed: ' . FFI::string($buf));
            }
            throw new RuntimeException('OpenGL program link failed');
        }
        return $prog;
    };

    $vs = $compileShader(GL_VERTEX_SHADER, "#version 460 core\nlayout(location=0) in vec3 pos;\nlayout(location=1) in vec3 col;\nout vec3 vCol;\nvoid main(){ vCol = col; gl_Position = vec4(pos.x, -pos.y, pos.z, 1.0); }\n");
    $fs = $compileShader(GL_FRAGMENT_SHADER, "#version 460 core\nin vec3 vCol;\nout vec4 outColor;\nvoid main(){ outColor = vec4(vCol, 1.0); }\n");
    $prog = $linkProgram($vs, $fs);

    $vao = ffi_new('unsigned int[1]', false);
    $gl['glGenVertexArrays'](1, FFI::addr($vao[0]));
    $gl['glBindVertexArray']($vao[0]);

    $vbos = ffi_new('unsigned int[2]', false);
    $gl['glGenBuffers'](2, FFI::addr($vbos[0]));

    $pos = ffi_new('float[9]', false);
    foreach ([0.0,0.5,0.0, 0.5,-0.5,0.0, -0.5,-0.5,0.0] as $i => $v) { $pos[$i] = $v; }
    $col = ffi_new('float[9]', false);
    foreach ([1.0,0.0,0.0, 0.0,1.0,0.0, 0.0,0.0,1.0] as $i => $v) { $col[$i] = $v; }

    $gl['glBindBuffer'](GL_ARRAY_BUFFER, $vbos[0]);
    $gl['glBufferData'](GL_ARRAY_BUFFER, 36, FFI::addr($pos[0]), GL_STATIC_DRAW);
    $gl['glVertexAttribPointer'](0, 3, GL_FLOAT, GL_FALSE, 0, null);
    $gl['glEnableVertexAttribArray'](0);

    $gl['glBindBuffer'](GL_ARRAY_BUFFER, $vbos[1]);
    $gl['glBufferData'](GL_ARRAY_BUFFER, 36, FFI::addr($col[0]), GL_STATIC_DRAW);
    $gl['glVertexAttribPointer'](1, 3, GL_FLOAT, GL_FALSE, 0, null);
    $gl['glEnableVertexAttribArray'](1);

    $gl['glBindVertexArray'](0);

    $glPanel['gl_hdc'] = $hdc;
    $glPanel['gl_hrc'] = $hrc;
    $glPanel['gl_interop_dev'] = $interopDev;
    $glPanel['gl_interop_obj'] = $interopObj;
    $glPanel['gl_fbo'] = $fbo[0];
    $glPanel['gl_program'] = $prog;
    $glPanel['gl_vao'] = $vao[0];
    $glPanel['gl'] = $gl;
    $glNative = true;

    log_msg('Init OpenGL interop panel done', $kernel32);
} catch (Throwable $e) {
    log_msg('OpenGL native path disabled: ' . $e->getMessage(), $kernel32);
}

$initD3D11TrianglePipeline($dxPanel);
if (!$glNative) {
    $initD3D11TrianglePipeline($glPanel);
}

// ---------------------------------------------------------------------------
// Vulkan native path: shaderc SPIR-V compilation + Vulkan offscreen render
// The rendered image is read back via a host-visible buffer and copied into a
// D3D11 staging texture, then CopyResource'd into the swapchain backbuffer.
// ---------------------------------------------------------------------------

$vulkan     = null;   // initialised inside try block; kept here for outer scope
$vkNative   = false;
$renderVulkan = null; // likewise
try {
    log_msg('Init Vulkan panel start', $kernel32);

    // Resolve shaderc_shared.dll: try script dir, then VULKAN_SDK/Bin, then PATH.
    $shadercPath = SCRIPT_DIR . '/shaderc_shared.dll';
    if (!file_exists($shadercPath)) {
        $vkSdkEnv = getenv('VULKAN_SDK');
        if ($vkSdkEnv !== false) {
            $candidate = $vkSdkEnv . '/Bin/shaderc_shared.dll';
            if (file_exists($candidate)) {
                $shadercPath = $candidate;
            }
        }
    }
    if (!file_exists($shadercPath)) {
        $shadercPath = 'shaderc_shared.dll';
    }
    log_msg("Loading shaderc from: $shadercPath", $kernel32);

    $shaderc = FFI::cdef('
        void* shaderc_compiler_initialize(void);
        void  shaderc_compiler_release(void* compiler);
        void* shaderc_compile_options_initialize(void);
        void  shaderc_compile_options_release(void* options);
        void  shaderc_compile_options_set_optimization_level(void* options, int level);
        void* shaderc_compile_into_spv(
            void* compiler,
            const char* source_text, size_t source_text_size,
            int shader_kind,
            const char* input_file_name, const char* entry_point_name,
            void* additional_options);
        void         shaderc_result_release(void* result);
        size_t       shaderc_result_get_length(void* result);
        void*        shaderc_result_get_bytes(void* result);
        int          shaderc_result_get_compilation_status(void* result);
        const char*  shaderc_result_get_error_message(void* result);
    ', $shadercPath);

    // Helper: compile GLSL source to SPIR-V bytes via shaderc.
    $compileSpv = function (string $src, int $kind, string $filename) use ($shaderc, $kernel32): string {
        $compiler = $shaderc->shaderc_compiler_initialize();
        if (FFI::isNull($compiler)) {
            throw new RuntimeException('shaderc_compiler_initialize failed');
        }
        $opts = $shaderc->shaderc_compile_options_initialize();
        if (FFI::isNull($opts)) {
            $shaderc->shaderc_compiler_release($compiler);
            throw new RuntimeException('shaderc_compile_options_initialize failed');
        }
        $shaderc->shaderc_compile_options_set_optimization_level($opts, 2);

        $result = $shaderc->shaderc_compile_into_spv(
            $compiler, $src, strlen($src), $kind, $filename, 'main', $opts
        );
        if (FFI::isNull($result)) {
            $shaderc->shaderc_compile_options_release($opts);
            $shaderc->shaderc_compiler_release($compiler);
            throw new RuntimeException('shaderc_compile_into_spv returned NULL');
        }

        $status = (int)$shaderc->shaderc_result_get_compilation_status($result);
        if ($status !== SHADERC_STATUS_SUCCESS) {
            // shaderc_result_get_error_message returns const char* — PHP FFI gives a PHP string.
            $errMsg = $shaderc->shaderc_result_get_error_message($result) ?? '(no message)';
            $shaderc->shaderc_result_release($result);
            $shaderc->shaderc_compile_options_release($opts);
            $shaderc->shaderc_compiler_release($compiler);
            throw new RuntimeException("shaderc failed ($filename): $errMsg");
        }

        $len = (int)$shaderc->shaderc_result_get_length($result);
        $bytesPtr = $shaderc->shaderc_result_get_bytes($result);
        $spv = FFI::string($bytesPtr, $len);

        $shaderc->shaderc_result_release($result);
        $shaderc->shaderc_compile_options_release($opts);
        $shaderc->shaderc_compiler_release($compiler);
        return $spv;
    };

    // Inline GLSL shaders.  The vertex shader uses gl_VertexIndex to produce
    // positions without any vertex buffer (same pattern as the D3D11 shader).
    $vertGlsl = "#version 450\n" .
        "layout(location = 0) out vec3 fragColor;\n" .
        "void main() {\n" .
        "    vec2 pos[3] = vec2[](vec2(0.0, -0.5), vec2(0.5, 0.5), vec2(-0.5, 0.5));\n" .
        "    vec3 col[3] = vec3[](vec3(1.0,0.0,0.0), vec3(0.0,1.0,0.0), vec3(0.0,0.0,1.0));\n" .
        "    gl_Position = vec4(pos[gl_VertexIndex], 0.0, 1.0);\n" .
        "    fragColor = col[gl_VertexIndex];\n" .
        "}\n";
    $fragGlsl = "#version 450\n" .
        "layout(location = 0) in vec3 fragColor;\n" .
        "layout(location = 0) out vec4 outColor;\n" .
        "void main() { outColor = vec4(fragColor, 1.0); }\n";

    $vertSpv = $compileSpv($vertGlsl, SHADERC_VERTEX_SHADER, 'vert.glsl');
    $fragSpv = $compileSpv($fragGlsl, SHADERC_FRAGMENT_SHADER, 'frag.glsl');
    log_msg('SPIR-V compilation succeeded', $kernel32);

    // Load vulkan-1.dll.  All struct parameters are passed as void* (raw byte
    // buffers built with vk_buf/vk_write_*).  Handle outputs use void*[1].
    log_msg('Loading vulkan-1.dll...', $kernel32);
    $vulkan = FFI::cdef('
        typedef int VkResult;
        VkResult vkCreateInstance(void* pCreateInfo, void* pAllocator, void** pInstance);
        VkResult vkEnumeratePhysicalDevices(void* instance, void* pCount, void* pDevices);
        void     vkGetPhysicalDeviceQueueFamilyProperties(void* physDev, void* pCount, void* pProps);
        VkResult vkCreateDevice(void* physDev, void* pCreateInfo, void* pAllocator, void** pDevice);
        void     vkGetDeviceQueue(void* device, unsigned int qfIndex, unsigned int queueIndex, void** pQueue);
        void     vkGetPhysicalDeviceMemoryProperties(void* physDev, void* pMemProps);
        VkResult vkCreateImage(void* device, void* pCreateInfo, void* pAllocator, void** pImage);
        void     vkGetImageMemoryRequirements(void* device, void* image, void* pMemReq);
        VkResult vkAllocateMemory(void* device, void* pAllocInfo, void* pAllocator, void** pMemory);
        VkResult vkBindImageMemory(void* device, void* image, void* memory, unsigned long long offset);
        VkResult vkCreateImageView(void* device, void* pCreateInfo, void* pAllocator, void** pView);
        VkResult vkCreateBuffer(void* device, void* pCreateInfo, void* pAllocator, void** pBuffer);
        void     vkGetBufferMemoryRequirements(void* device, void* buffer, void* pMemReq);
        VkResult vkBindBufferMemory(void* device, void* buffer, void* memory, unsigned long long offset);
        VkResult vkCreateRenderPass(void* device, void* pCreateInfo, void* pAllocator, void** pRenderPass);
        VkResult vkCreateFramebuffer(void* device, void* pCreateInfo, void* pAllocator, void** pFramebuffer);
        VkResult vkCreateShaderModule(void* device, void* pCreateInfo, void* pAllocator, void** pShaderModule);
        void     vkDestroyShaderModule(void* device, void* shaderModule, void* pAllocator);
        VkResult vkCreatePipelineLayout(void* device, void* pCreateInfo, void* pAllocator, void** pPipelineLayout);
        VkResult vkCreateGraphicsPipelines(void* device, void* pipelineCache, unsigned int count, void* pCreateInfos, void* pAllocator, void** pPipelines);
        VkResult vkCreateCommandPool(void* device, void* pCreateInfo, void* pAllocator, void** pCommandPool);
        VkResult vkAllocateCommandBuffers(void* device, void* pAllocateInfo, void* pCommandBuffers);
        VkResult vkCreateFence(void* device, void* pCreateInfo, void* pAllocator, void** pFence);
        VkResult vkWaitForFences(void* device, unsigned int count, void* pFences, unsigned int waitAll, unsigned long long timeout);
        VkResult vkResetFences(void* device, unsigned int count, void* pFences);
        VkResult vkResetCommandBuffer(void* commandBuffer, unsigned int flags);
        VkResult vkBeginCommandBuffer(void* commandBuffer, void* pBeginInfo);
        VkResult vkEndCommandBuffer(void* commandBuffer);
        void     vkCmdBeginRenderPass(void* commandBuffer, void* pRenderPassBegin, unsigned int contents);
        void     vkCmdEndRenderPass(void* commandBuffer);
        void     vkCmdBindPipeline(void* commandBuffer, unsigned int bindPoint, void* pipeline);
        void     vkCmdDraw(void* commandBuffer, unsigned int vertexCount, unsigned int instanceCount, unsigned int firstVertex, unsigned int firstInstance);
        void     vkCmdCopyImageToBuffer(void* commandBuffer, void* srcImage, unsigned int srcLayout, void* dstBuffer, unsigned int regionCount, void* pRegions);
        VkResult vkQueueSubmit(void* queue, unsigned int submitCount, void* pSubmits, void* fence);
        VkResult vkMapMemory(void* device, void* memory, unsigned long long offset, unsigned long long size, unsigned int flags, void** ppData);
        void     vkUnmapMemory(void* device, void* memory);
        VkResult vkDeviceWaitIdle(void* device);
    ', 'vulkan-1.dll');
    log_msg('vulkan-1.dll loaded', $kernel32);

    // Helper: allocate a void*[1] output slot, call fn, return the handle.
    // Used for all vkCreate* functions.
    $ppOut = ffi_new('void*[1]', false);  // reused scratch below

    // --- Create VkInstance ---
    $appName   = cstr('php_dcomp');
    $engName   = cstr('none');
    $appInfo   = vk_buf(48);
    vk_write_u32($appInfo, 0, VK_STRUCTURE_TYPE_APPLICATION_INFO);
    vk_write_u64($appInfo, 16, ptr_i(FFI::addr($appName[0])));
    vk_write_u32($appInfo, 24, 1);
    vk_write_u64($appInfo, 32, ptr_i(FFI::addr($engName[0])));
    vk_write_u32($appInfo, 40, 1);
    vk_write_u32($appInfo, 44, 1 << 22);   // VK_API_VERSION_1_0

    $instCI = vk_buf(64);
    vk_write_u32($instCI, 0, VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO);
    vk_write_u64($instCI, 24, ptr_i(FFI::addr($appInfo[0])));

    log_msg('Calling vkCreateInstance...', $kernel32);
    $ppInst = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateInstance(FFI::addr($instCI[0]), null, FFI::addr($ppInst[0])), 'vkCreateInstance');
    $vkInstance = $ppInst[0];
    log_msg('vkCreateInstance OK', $kernel32);

    // --- Enumerate physical devices ---
    log_msg('Calling vkEnumeratePhysicalDevices...', $kernel32);
    $pCount = ffi_new('unsigned int[1]', false);
    $pCount[0] = 0;
    vk_check((int)$vulkan->vkEnumeratePhysicalDevices($vkInstance, FFI::addr($pCount[0]), null), 'vkEnumeratePhysicalDevices(count)');
    $devCount = (int)$pCount[0];
    log_msg("Physical device count: $devCount", $kernel32);
    if ($devCount === 0) {
        throw new RuntimeException('No Vulkan physical devices found');
    }
    $pDevList = ffi_new("void*[$devCount]", false);
    vk_check((int)$vulkan->vkEnumeratePhysicalDevices($vkInstance, FFI::addr($pCount[0]), FFI::addr($pDevList[0])), 'vkEnumeratePhysicalDevices(list)');

    // Find first physical device with a graphics queue family.
    $vkPhysDev = null;
    $vkQfIndex = -1;
    for ($di = 0; $di < $devCount; $di++) {
        $pd = $pDevList[$di];
        $qCount = ffi_new('unsigned int[1]', false);
        $qCount[0] = 0;
        $vulkan->vkGetPhysicalDeviceQueueFamilyProperties($pd, FFI::addr($qCount[0]), null);
        $qc = (int)$qCount[0];
        if ($qc === 0) {
            continue;
        }
        // VkQueueFamilyProperties = 24 bytes each: queueFlags(4) + queueCount(4) + ...
        $qProps = vk_buf($qc * 24);
        $vulkan->vkGetPhysicalDeviceQueueFamilyProperties($pd, FFI::addr($qCount[0]), FFI::addr($qProps[0]));
        for ($qi = 0; $qi < $qc; $qi++) {
            if ((vk_read_u32($qProps, $qi * 24) & VK_QUEUE_GRAPHICS_BIT) !== 0) {
                $vkPhysDev = $pd;
                $vkQfIndex = $qi;
                break 2;
            }
        }
    }
    if ($vkPhysDev === null) {
        throw new RuntimeException('No Vulkan graphics queue family found');
    }

    // --- Create logical device ---
    $prio = ffi_new('float[1]', false);
    $prio[0] = 1.0;
    $qCI = vk_buf(40);
    vk_write_u32($qCI, 0, VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO);
    vk_write_u32($qCI, 20, $vkQfIndex);
    vk_write_u32($qCI, 24, 1);
    vk_write_u64($qCI, 32, ptr_i(FFI::addr($prio[0])));

    $devCI = vk_buf(72);
    vk_write_u32($devCI, 0, VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO);
    vk_write_u32($devCI, 20, 1);
    vk_write_u64($devCI, 24, ptr_i(FFI::addr($qCI[0])));

    log_msg('Calling vkCreateDevice...', $kernel32);
    $ppDev = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateDevice($vkPhysDev, FFI::addr($devCI[0]), null, FFI::addr($ppDev[0])), 'vkCreateDevice');
    $vkDevice = $ppDev[0];
    log_msg('vkCreateDevice OK', $kernel32);

    $ppQueue = ffi_new('void*[1]', false);
    $vulkan->vkGetDeviceQueue($vkDevice, $vkQfIndex, 0, FFI::addr($ppQueue[0]));
    $vkQueue = $ppQueue[0];

    // --- Query memory properties ---
    // VkPhysicalDeviceMemoryProperties is 520 bytes (see find_vk_memory_type comments).
    log_msg('Calling vkGetPhysicalDeviceMemoryProperties...', $kernel32);
    $memProps = vk_buf(520);
    $vulkan->vkGetPhysicalDeviceMemoryProperties($vkPhysDev, FFI::addr($memProps[0]));
    log_msg('Memory properties OK', $kernel32);

    // --- Create offscreen image (VK_FORMAT_B8G8R8A8_UNORM to match D3D11) ---
    log_msg('Allocating imgCI buffer...', $kernel32);
    $imgCI = vk_buf(88);
    log_msg('imgCI allocated', $kernel32);
    vk_write_u32($imgCI, 0, VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO);
    vk_write_u32($imgCI, 20, VK_IMAGE_TYPE_2D);
    vk_write_u32($imgCI, 24, VK_FORMAT_B8G8R8A8_UNORM);
    vk_write_u32($imgCI, 28, PANEL_W);
    vk_write_u32($imgCI, 32, PANEL_H);
    vk_write_u32($imgCI, 36, 1);    // depth
    vk_write_u32($imgCI, 40, 1);    // mipLevels
    vk_write_u32($imgCI, 44, 1);    // arrayLayers
    vk_write_u32($imgCI, 48, VK_SAMPLE_COUNT_1_BIT);
    vk_write_u32($imgCI, 52, VK_IMAGE_TILING_OPTIMAL);
    vk_write_u32($imgCI, 56, VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT);
    vk_write_u32($imgCI, 60, VK_SHARING_MODE_EXCLUSIVE);
    vk_write_u32($imgCI, 80, VK_IMAGE_LAYOUT_UNDEFINED);

    log_msg('Calling vkCreateImage...', $kernel32);
    $ppImg = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateImage($vkDevice, FFI::addr($imgCI[0]), null, FFI::addr($ppImg[0])), 'vkCreateImage');
    $vkOffImage = $ppImg[0];
    log_msg('vkCreateImage OK', $kernel32);

    // Bind device-local memory to the offscreen image.
    $imgMemReq = vk_buf(24);
    $vulkan->vkGetImageMemoryRequirements($vkDevice, $vkOffImage, FFI::addr($imgMemReq[0]));
    $imgMemSize  = vk_read_u64($imgMemReq, 0);
    $imgTypeBits = vk_read_u32($imgMemReq, 16);
    log_msg("imgMemSize=$imgMemSize imgTypeBits=$imgTypeBits", $kernel32);

    $imgMemAI = vk_buf(32);
    vk_write_u32($imgMemAI, 0, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO);
    vk_write_u64($imgMemAI, 16, $imgMemSize);
    vk_write_u32($imgMemAI, 24, find_vk_memory_type($memProps, $imgTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT));

    log_msg('Calling vkAllocateMemory(image)...', $kernel32);
    $ppImgMem = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkAllocateMemory($vkDevice, FFI::addr($imgMemAI[0]), null, FFI::addr($ppImgMem[0])), 'vkAllocateMemory(image)');
    $vkOffMemory = $ppImgMem[0];
    log_msg('Calling vkBindImageMemory...', $kernel32);
    vk_check((int)$vulkan->vkBindImageMemory($vkDevice, $vkOffImage, $vkOffMemory, 0), 'vkBindImageMemory');
    log_msg('vkBindImageMemory OK', $kernel32);

    // Image view for use as colour attachment.
    log_msg('Calling vkCreateImageView...', $kernel32);
    $ivCI = vk_buf(80);
    vk_write_u32($ivCI, 0, VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO);
    vk_write_u64($ivCI, 24, ptr_i($vkOffImage));
    vk_write_u32($ivCI, 32, VK_IMAGE_VIEW_TYPE_2D);
    vk_write_u32($ivCI, 36, VK_FORMAT_B8G8R8A8_UNORM);
    vk_write_u32($ivCI, 56, VK_IMAGE_ASPECT_COLOR_BIT);
    vk_write_u32($ivCI, 64, 1);    // levelCount
    vk_write_u32($ivCI, 72, 1);    // layerCount

    $ppView = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateImageView($vkDevice, FFI::addr($ivCI[0]), null, FFI::addr($ppView[0])), 'vkCreateImageView');
    $vkOffView = $ppView[0];
    log_msg('vkCreateImageView OK', $kernel32);

    // --- Host-visible readback buffer ---
    log_msg('Calling vkCreateBuffer...', $kernel32);
    $vkBufSize = PANEL_W * PANEL_H * 4;
    $bufCI = vk_buf(56);
    vk_write_u32($bufCI, 0, VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO);
    vk_write_u64($bufCI, 24, $vkBufSize);
    vk_write_u32($bufCI, 32, VK_BUFFER_USAGE_TRANSFER_DST_BIT);
    vk_write_u32($bufCI, 36, VK_SHARING_MODE_EXCLUSIVE);

    $ppRdBuf = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateBuffer($vkDevice, FFI::addr($bufCI[0]), null, FFI::addr($ppRdBuf[0])), 'vkCreateBuffer');
    $vkReadbackBuffer = $ppRdBuf[0];
    log_msg('vkCreateBuffer OK', $kernel32);

    $bufMemReq = vk_buf(24);
    $vulkan->vkGetBufferMemoryRequirements($vkDevice, $vkReadbackBuffer, FFI::addr($bufMemReq[0]));
    $bufMemSize  = vk_read_u64($bufMemReq, 0);
    $bufTypeBits = vk_read_u32($bufMemReq, 16);

    $bufMemAI = vk_buf(32);
    vk_write_u32($bufMemAI, 0, VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO);
    vk_write_u64($bufMemAI, 16, $bufMemSize);
    vk_write_u32($bufMemAI, 24, find_vk_memory_type(
        $memProps, $bufTypeBits,
        VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
    ));

    $ppRdMem = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkAllocateMemory($vkDevice, FFI::addr($bufMemAI[0]), null, FFI::addr($ppRdMem[0])), 'vkAllocateMemory(buffer)');
    $vkReadbackMemory = $ppRdMem[0];
    vk_check((int)$vulkan->vkBindBufferMemory($vkDevice, $vkReadbackBuffer, $vkReadbackMemory, 0), 'vkBindBufferMemory');

    // --- Render pass ---
    // attachment: LOAD_OP_CLEAR, STORE_OP_STORE, finalLayout = TRANSFER_SRC_OPTIMAL
    $att = vk_buf(36);
    vk_write_u32($att, 4,  VK_FORMAT_B8G8R8A8_UNORM);
    vk_write_u32($att, 8,  VK_SAMPLE_COUNT_1_BIT);
    vk_write_u32($att, 12, VK_ATTACHMENT_LOAD_OP_CLEAR);
    vk_write_u32($att, 16, VK_ATTACHMENT_STORE_OP_STORE);
    vk_write_u32($att, 20, VK_ATTACHMENT_LOAD_OP_DONT_CARE);
    vk_write_u32($att, 24, VK_ATTACHMENT_STORE_OP_DONT_CARE);
    vk_write_u32($att, 28, VK_IMAGE_LAYOUT_UNDEFINED);
    vk_write_u32($att, 32, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL);

    $attRef = vk_buf(8);
    vk_write_u32($attRef, 4, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL);

    $sub = vk_buf(72);
    vk_write_u32($sub, 4, VK_PIPELINE_BIND_POINT_GRAPHICS);
    vk_write_u32($sub, 24, 1);
    vk_write_u64($sub, 32, ptr_i(FFI::addr($attRef[0])));

    $rpCI = vk_buf(64);
    vk_write_u32($rpCI, 0, VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO);
    vk_write_u32($rpCI, 20, 1);
    vk_write_u64($rpCI, 24, ptr_i(FFI::addr($att[0])));
    vk_write_u32($rpCI, 32, 1);
    vk_write_u64($rpCI, 40, ptr_i(FFI::addr($sub[0])));

    $ppRP = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateRenderPass($vkDevice, FFI::addr($rpCI[0]), null, FFI::addr($ppRP[0])), 'vkCreateRenderPass');
    $vkRenderPass = $ppRP[0];

    // --- Framebuffer ---
    $fbAtts = ffi_new('void*[1]', false);
    $fbAtts[0] = $vkOffView;
    $fbCI = vk_buf(64);
    vk_write_u32($fbCI, 0, VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO);
    vk_write_u64($fbCI, 24, ptr_i($vkRenderPass));
    vk_write_u32($fbCI, 32, 1);
    vk_write_u64($fbCI, 40, ptr_i(FFI::addr($fbAtts[0])));
    vk_write_u32($fbCI, 48, PANEL_W);
    vk_write_u32($fbCI, 52, PANEL_H);
    vk_write_u32($fbCI, 56, 1);

    $ppFB = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateFramebuffer($vkDevice, FFI::addr($fbCI[0]), null, FFI::addr($ppFB[0])), 'vkCreateFramebuffer');
    $vkFramebuffer = $ppFB[0];

    // --- Shader modules ---
    $vertWords = cstr($vertSpv);   // reuse cstr for raw binary; byte-exact copy
    $fragWords = cstr($fragSpv);

    $vsmCI = vk_buf(40);
    vk_write_u32($vsmCI, 0, VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    vk_write_u64($vsmCI, 24, strlen($vertSpv));
    vk_write_u64($vsmCI, 32, ptr_i(FFI::addr($vertWords[0])));
    $ppVsMod = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateShaderModule($vkDevice, FFI::addr($vsmCI[0]), null, FFI::addr($ppVsMod[0])), 'vkCreateShaderModule(vs)');
    $vsMod = $ppVsMod[0];

    $fsmCI = vk_buf(40);
    vk_write_u32($fsmCI, 0, VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO);
    vk_write_u64($fsmCI, 24, strlen($fragSpv));
    vk_write_u64($fsmCI, 32, ptr_i(FFI::addr($fragWords[0])));
    $ppFsMod = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateShaderModule($vkDevice, FFI::addr($fsmCI[0]), null, FFI::addr($ppFsMod[0])), 'vkCreateShaderModule(fs)');
    $fsMod = $ppFsMod[0];

    // --- Pipeline ---
    $mainName = cstr('main');
    // Two VkPipelineShaderStageCreateInfo (48 bytes each) packed together.
    $stages = vk_buf(96);
    vk_write_u32($stages, 0,  VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
    vk_write_u32($stages, 20, 1);   // VK_SHADER_STAGE_VERTEX_BIT
    vk_write_u64($stages, 24, ptr_i($vsMod));
    vk_write_u64($stages, 32, ptr_i(FFI::addr($mainName[0])));
    vk_write_u32($stages, 48, VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO);
    vk_write_u32($stages, 68, 0x10); // VK_SHADER_STAGE_FRAGMENT_BIT
    vk_write_u64($stages, 72, ptr_i($fsMod));
    vk_write_u64($stages, 80, ptr_i(FFI::addr($mainName[0])));

    $vi = vk_buf(48);
    vk_write_u32($vi, 0, VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO);
    $ia = vk_buf(32);
    vk_write_u32($ia, 0, VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO);
    vk_write_u32($ia, 20, VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST);

    $vp = vk_buf(24);
    vk_write_f32($vp, 0,  0.0);
    vk_write_f32($vp, 4,  0.0);
    vk_write_f32($vp, 8,  (float)PANEL_W);
    vk_write_f32($vp, 12, (float)PANEL_H);
    vk_write_f32($vp, 16, 0.0);
    vk_write_f32($vp, 20, 1.0);
    $sc2d = vk_buf(16);
    vk_write_u32($sc2d, 8,  PANEL_W);
    vk_write_u32($sc2d, 12, PANEL_H);

    $vpState = vk_buf(48);
    vk_write_u32($vpState, 0, VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO);
    vk_write_u32($vpState, 20, 1);
    vk_write_u64($vpState, 24, ptr_i(FFI::addr($vp[0])));
    vk_write_u32($vpState, 32, 1);
    vk_write_u64($vpState, 40, ptr_i(FFI::addr($sc2d[0])));

    $rs = vk_buf(64);
    vk_write_u32($rs, 0, VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO);
    vk_write_u32($rs, 28, VK_POLYGON_MODE_FILL);
    vk_write_u32($rs, 32, VK_CULL_MODE_NONE);
    vk_write_u32($rs, 36, VK_FRONT_FACE_COUNTER_CLOCKWISE);
    vk_write_f32($rs, 56, 1.0);

    $ms = vk_buf(48);
    vk_write_u32($ms, 0, VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO);
    vk_write_u32($ms, 20, VK_SAMPLE_COUNT_1_BIT);

    $cbAtt = vk_buf(32);
    vk_write_u32($cbAtt, 28, VK_COLOR_COMPONENT_RGBA_BITS);
    $cbState = vk_buf(56);
    vk_write_u32($cbState, 0, VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO);
    vk_write_u32($cbState, 28, 1);
    vk_write_u64($cbState, 32, ptr_i(FFI::addr($cbAtt[0])));

    $plCI = vk_buf(48);
    vk_write_u32($plCI, 0, VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO);
    $ppLayout = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreatePipelineLayout($vkDevice, FFI::addr($plCI[0]), null, FFI::addr($ppLayout[0])), 'vkCreatePipelineLayout');
    $vkPipelineLayout = $ppLayout[0];

    $gpCI = vk_buf(144);
    vk_write_u32($gpCI, 0, VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO);
    vk_write_u32($gpCI, 20, 2);   // stageCount
    vk_write_u64($gpCI, 24, ptr_i(FFI::addr($stages[0])));
    vk_write_u64($gpCI, 32, ptr_i(FFI::addr($vi[0])));
    vk_write_u64($gpCI, 40, ptr_i(FFI::addr($ia[0])));
    vk_write_u64($gpCI, 56, ptr_i(FFI::addr($vpState[0])));
    vk_write_u64($gpCI, 64, ptr_i(FFI::addr($rs[0])));
    vk_write_u64($gpCI, 72, ptr_i(FFI::addr($ms[0])));
    vk_write_u64($gpCI, 88, ptr_i(FFI::addr($cbState[0])));
    vk_write_u64($gpCI, 104, ptr_i($vkPipelineLayout));
    vk_write_u64($gpCI, 112, ptr_i($vkRenderPass));

    $ppPipeline = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateGraphicsPipelines($vkDevice, null, 1, FFI::addr($gpCI[0]), null, FFI::addr($ppPipeline[0])), 'vkCreateGraphicsPipelines');
    $vkPipeline = $ppPipeline[0];
    $vulkan->vkDestroyShaderModule($vkDevice, $vsMod, null);
    $vulkan->vkDestroyShaderModule($vkDevice, $fsMod, null);

    // --- Command pool + buffer ---
    $cpCI = vk_buf(24);
    vk_write_u32($cpCI, 0, VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO);
    vk_write_u32($cpCI, 16, VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT);
    vk_write_u32($cpCI, 20, $vkQfIndex);
    $ppCmdPool = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateCommandPool($vkDevice, FFI::addr($cpCI[0]), null, FFI::addr($ppCmdPool[0])), 'vkCreateCommandPool');
    $vkCmdPool = $ppCmdPool[0];

    $cbAI = vk_buf(32);
    vk_write_u32($cbAI, 0, VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO);
    vk_write_u64($cbAI, 16, ptr_i($vkCmdPool));
    vk_write_u32($cbAI, 24, VK_COMMAND_BUFFER_LEVEL_PRIMARY);
    vk_write_u32($cbAI, 28, 1);
    $ppCmdBuf = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkAllocateCommandBuffers($vkDevice, FFI::addr($cbAI[0]), FFI::addr($ppCmdBuf[0])), 'vkAllocateCommandBuffers');
    $vkCmdBuf = $ppCmdBuf[0];

    // --- Fence (created signalled so first WaitForFences succeeds immediately) ---
    $fenceCI = vk_buf(24);
    vk_write_u32($fenceCI, 0, VK_STRUCTURE_TYPE_FENCE_CREATE_INFO);
    vk_write_u32($fenceCI, 16, VK_FENCE_CREATE_SIGNALED_BIT);
    $ppFence = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkCreateFence($vkDevice, FFI::addr($fenceCI[0]), null, FFI::addr($ppFence[0])), 'vkCreateFence');
    $vkFence = $ppFence[0];

    // --- D3D11 staging texture for CPU→GPU copy ---
    $vkStagingTex = $createStagingTexture(PANEL_W, PANEL_H);

    // Store all Vulkan state in the panel array for use in the render closure.
    $vkPanel['vk_instance']        = $vkInstance;
    $vkPanel['vk_device']          = $vkDevice;
    $vkPanel['vk_queue']           = $vkQueue;
    $vkPanel['vk_cmd_buf']         = $vkCmdBuf;
    $vkPanel['vk_fence']           = $vkFence;
    $vkPanel['vk_render_pass']     = $vkRenderPass;
    $vkPanel['vk_framebuffer']     = $vkFramebuffer;
    $vkPanel['vk_pipeline']        = $vkPipeline;
    $vkPanel['vk_off_image']       = $vkOffImage;
    $vkPanel['vk_readback_buf']    = $vkReadbackBuffer;
    $vkPanel['vk_readback_mem']    = $vkReadbackMemory;
    $vkPanel['vk_buf_size']        = $vkBufSize;
    $vkPanel['vk_staging_tex']     = $vkStagingTex;
    $vkNative = true;

    log_msg('Init Vulkan panel done', $kernel32);
} catch (Throwable $e) {
    log_msg('Vulkan native path disabled: ' . $e->getMessage(), $kernel32);
    $initD3D11TrianglePipeline($vkPanel);
}

// Render closure for the Vulkan panel.  Called each frame when $vkNative is true.
$renderVulkan = function (array &$panel) use ($vulkan, $swapchainPresent, $ctxMap, $ctxUnmap, $ctxCopyResource, $basicTypes, $kernel32): bool {
    $device  = $panel['vk_device'];
    $queue   = $panel['vk_queue'];
    $cmdBuf  = $panel['vk_cmd_buf'];
    $fence   = $panel['vk_fence'];

    // Wait for the previous frame's fence and reset it.
    $pFences = ffi_new('void*[1]', false);
    $pFences[0] = $fence;
    vk_check((int)$vulkan->vkWaitForFences($device, 1, FFI::addr($pFences[0]), 1, -1), 'vkWaitForFences');
    vk_check((int)$vulkan->vkResetFences($device, 1, FFI::addr($pFences[0])), 'vkResetFences');
    vk_check((int)$vulkan->vkResetCommandBuffer($cmdBuf, 0), 'vkResetCommandBuffer');

    // Begin command buffer recording.
    $cbBI = vk_buf(32);
    vk_write_u32($cbBI, 0, VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO);
    vk_check((int)$vulkan->vkBeginCommandBuffer($cmdBuf, FFI::addr($cbBI[0])), 'vkBeginCommandBuffer');

    // Clear colour (dark red background to distinguish Vulkan panel).
    $clearVal = ffi_new('float[4]', false);
    $clearVal[0] = 0.15; $clearVal[1] = 0.05; $clearVal[2] = 0.05; $clearVal[3] = 1.0;
    $rpBI = vk_buf(64);
    vk_write_u32($rpBI, 0, VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO);
    vk_write_u64($rpBI, 16, ptr_i($panel['vk_render_pass']));
    vk_write_u64($rpBI, 24, ptr_i($panel['vk_framebuffer']));
    vk_write_u32($rpBI, 40, PANEL_W);
    vk_write_u32($rpBI, 44, PANEL_H);
    vk_write_u32($rpBI, 48, 1);   // clearValueCount
    vk_write_u64($rpBI, 56, ptr_i(FFI::addr($clearVal[0])));

    $vulkan->vkCmdBeginRenderPass($cmdBuf, FFI::addr($rpBI[0]), 0);
    $vulkan->vkCmdBindPipeline($cmdBuf, VK_PIPELINE_BIND_POINT_GRAPHICS, $panel['vk_pipeline']);
    $vulkan->vkCmdDraw($cmdBuf, 3, 1, 0, 0);
    $vulkan->vkCmdEndRenderPass($cmdBuf);

    // Copy rendered image to host-visible readback buffer.
    // VkBufferImageCopy layout (56 bytes):
    //   offset 0:  bufferOffset (u64)
    //   offset 8:  bufferRowLength (u32)
    //   offset 12: bufferImageHeight (u32)
    //   offset 16: imageSubresource.aspectMask (u32)
    //   offset 20: imageSubresource.mipLevel (u32)
    //   offset 24: imageSubresource.baseArrayLayer (u32)
    //   offset 28: imageSubresource.layerCount (u32)
    //   offset 32: imageOffset.x/y/z (3×u32)
    //   offset 44: imageExtent.width (u32)
    //   offset 48: imageExtent.height (u32)
    //   offset 52: imageExtent.depth (u32)
    $region = vk_buf(56);
    vk_write_u32($region, 16, VK_IMAGE_ASPECT_COLOR_BIT);
    vk_write_u32($region, 28, 1);   // layerCount
    vk_write_u32($region, 44, PANEL_W);
    vk_write_u32($region, 48, PANEL_H);
    vk_write_u32($region, 52, 1);   // depth
    $vulkan->vkCmdCopyImageToBuffer(
        $cmdBuf, $panel['vk_off_image'], VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        $panel['vk_readback_buf'], 1, FFI::addr($region[0])
    );

    vk_check((int)$vulkan->vkEndCommandBuffer($cmdBuf), 'vkEndCommandBuffer');

    // Submit and wait.
    $pCmdBufs = ffi_new('void*[1]', false);
    $pCmdBufs[0] = $cmdBuf;
    $submitInfo = vk_buf(72);
    vk_write_u32($submitInfo, 0, VK_STRUCTURE_TYPE_SUBMIT_INFO);
    vk_write_u32($submitInfo, 40, 1);
    vk_write_u64($submitInfo, 48, ptr_i(FFI::addr($pCmdBufs[0])));
    vk_check((int)$vulkan->vkQueueSubmit($queue, 1, FFI::addr($submitInfo[0]), $fence), 'vkQueueSubmit');
    vk_check((int)$vulkan->vkWaitForFences($device, 1, FFI::addr($pFences[0]), 1, -1), 'vkWaitForFences(post)');

    // Map Vulkan readback buffer.
    $ppVkData = ffi_new('void*[1]', false);
    vk_check((int)$vulkan->vkMapMemory($device, $panel['vk_readback_mem'], 0, $panel['vk_buf_size'], 0, FFI::addr($ppVkData[0])), 'vkMapMemory');

    // Map D3D11 staging texture.
    $mapped = $ctxMap($panel['vk_staging_tex']);

    // Copy pixel data row by row (handles non-power-of-two row pitch).
    $vkPitch  = PANEL_W * 4;
    $rowPitch = (int)$mapped->RowPitch;
    $srcPtr   = $basicTypes->cast('char*', $ppVkData[0]);
    $dstPtr   = $basicTypes->cast('char*', $mapped->pData);
    if ($rowPitch === $vkPitch) {
        FFI::memcpy(FFI::addr($dstPtr[0]), FFI::addr($srcPtr[0]), $vkPitch * PANEL_H);
    } else {
        for ($y = 0; $y < PANEL_H; $y++) {
            FFI::memcpy(
                FFI::addr($dstPtr[$y * $rowPitch]),
                FFI::addr($srcPtr[$y * $vkPitch]),
                $vkPitch
            );
        }
    }

    $ctxUnmap($panel['vk_staging_tex']);
    $vulkan->vkUnmapMemory($device, $panel['vk_readback_mem']);

    // Copy staging texture to swapchain backbuffer.
    $ctxCopyResource($panel['bb'], $panel['vk_staging_tex']);

    $hr = $swapchainPresent($panel['sc']);
    if ($hr < 0) {
        log_msg(sprintf('Vulkan panel Present failed: 0x%08X', $hr & 0xFFFFFFFF), $kernel32);
        return false;
    }
    if (!isset($panel['first_present_logged'])) {
        log_msg($panel['name'] . ' first present succeeded', $kernel32);
        $panel['first_present_logged'] = true;
    }
    return true;
};

$commit = com_fn($dcompDevice, 3, 'DCompCommitFunc');
$commit($dcompDevice);

log_msg('Panels created. Entering render loop...', $kernel32);
log_msg($glNative ? 'Left panel: OpenGL slot (native OpenGL via WGL_NV_DX_interop)' : 'Left panel: OpenGL slot (compatibility triangle via D3D11)', $kernel32);
log_msg('Center panel: DirectX slot (native D3D11 triangle)', $kernel32);
log_msg($vkNative ? 'Right panel: Vulkan slot (native Vulkan offscreen + D3D11 copy)' : 'Right panel: Vulkan slot (compatibility triangle via D3D11)', $kernel32);

$renderGL = function (array &$panel, array $bg) use ($opengl32, $swapchainPresent, $kernel32): bool {
    if (!isset($panel['gl_hrc'])) {
        return false;
    }

    $gl = $panel['gl'];
    $opengl32->wglMakeCurrent($panel['gl_hdc'], $panel['gl_hrc']);

    $objs = ffi_new('void*[1]', false);
    $objs[0] = $panel['gl_interop_obj'];
    $lockOk = $gl['wglDXLockObjectsNV']($panel['gl_interop_dev'], 1, FFI::addr($objs[0]));
    if (!$lockOk) {
        log_msg('wglDXLockObjectsNV failed; using fallback renderer for this frame', $kernel32);
        return false;
    }

    $gl['glBindFramebuffer'](GL_FRAMEBUFFER, $panel['gl_fbo']);
    $opengl32->glViewport(0, 0, PANEL_W, PANEL_H);
    $opengl32->glClearColor($bg[0], $bg[1], $bg[2], 1.0);
    $opengl32->glClear(GL_COLOR_BUFFER_BIT);
    $gl['glUseProgram']($panel['gl_program']);
    $gl['glBindVertexArray']($panel['gl_vao']);
    $gl['glDrawArrays'](GL_TRIANGLES, 0, 3);
    $gl['glBindVertexArray'](0);
    $opengl32->glFlush();
    $gl['glBindFramebuffer'](GL_FRAMEBUFFER, 0);

    $gl['wglDXUnlockObjectsNV']($panel['gl_interop_dev'], 1, FFI::addr($objs[0]));

    $hr = $swapchainPresent($panel['sc']);
    if ($hr < 0) {
        log_msg(sprintf('OpenGL panel Present failed: 0x%08X', $hr & 0xFFFFFFFF), $kernel32);
        return false;
    }
    if (!isset($panel['first_present_logged'])) {
        log_msg($panel['name'] . ' first present succeeded', $kernel32);
        $panel['first_present_logged'] = true;
    }
    return true;
};

$msg = $user32->new('MSG');
$frame = 0;
log_msg('Entering render loop', $kernel32);
while (true) {
    if ($user32->IsWindow($hwnd) == 0) {
        break;
    }

    while ($user32->PeekMessageA(FFI::addr($msg), null, 0, 0, PM_REMOVE) != 0) {
        if ((int)$msg->message === WM_QUIT) {
            break 2;
        }
        $user32->TranslateMessage(FFI::addr($msg));
        $user32->DispatchMessageA(FFI::addr($msg));
    }

    if ($glNative) {
        $ok = $renderGL($glPanel, [0.06, 0.10, 0.28]);
        if (!$ok) {
            $renderTrianglePanel($glPanel, [0.06, 0.10, 0.28]);
        }
    } else {
        $renderTrianglePanel($glPanel, [0.06, 0.10, 0.28]);
    }

    $renderTrianglePanel($dxPanel, [0.06, 0.22, 0.08]);

    if ($vkNative && $renderVulkan !== null) {
        $ok = $renderVulkan($vkPanel);
        if (!$ok) {
            $renderTrianglePanel($vkPanel, [0.24, 0.08, 0.08]);
        }
    } else {
        $renderTrianglePanel($vkPanel, [0.24, 0.08, 0.08]);
    }

    $frame++;
    if ($frame === 1) {
        log_msg('Frame 1 rendered successfully', $kernel32);
    }
    if (($frame % 120) === 0) {
        log_msg("Frame $frame", $kernel32);
    }
    $kernel32->Sleep(1);
}

log_msg("Render loop exited at frame $frame", $kernel32);

if ($glNative) {
    $gl = $glPanel['gl'];
    if (isset($glPanel['gl_interop_dev'], $glPanel['gl_interop_obj'])) {
        $gl['wglDXUnregisterObjectNV']($glPanel['gl_interop_dev'], $glPanel['gl_interop_obj']);
    }
    if (isset($glPanel['gl_interop_dev'])) {
        $gl['wglDXCloseDeviceNV']($glPanel['gl_interop_dev']);
    }
    $opengl32->wglMakeCurrent(null, null);
    $opengl32->wglDeleteContext($glPanel['gl_hrc']);
    $user32->ReleaseDC($hwnd, $glPanel['gl_hdc']);
}

if ($vkNative && isset($vkPanel['vk_device'])) {
    $vulkan->vkDeviceWaitIdle($vkPanel['vk_device']);
    if (isset($vkPanel['vk_staging_tex'])) {
        com_release($vkPanel['vk_staging_tex']);
    }
}

foreach ([$glPanel, $dxPanel, $vkPanel] as $p) {
    if (isset($p['ps'])) {
        com_release($p['ps']);
    }
    if (isset($p['vs'])) {
        com_release($p['vs']);
    }
    com_release($p['vis']);
    com_release($p['rtv']);
    com_release($p['bb']);
    com_release($p['sc']);
}

com_release($rootVisual);
com_release($dcompTarget);
com_release($dcompDevice);
com_release($ctx);
com_release($device);

log_msg('=== END ===', $kernel32);
