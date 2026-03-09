// hello.d - WinUI3 XAML Island Triangle Sample using D language
//
// Draws a gradient-filled triangle via WinUI3 XAML DesktopWindowXamlSource
// using raw COM vtable calls. No C++/WinRT or cppwinrt dependency.
//
// All Windows and COM types are declared inline to avoid conflicts
// with D standard library COM interface definitions.

module hello;

import core.stdc.stdio  : vsnprintf, snprintf;
import core.stdc.stdarg : va_list, va_start, va_end;
import core.stdc.string : memset;

// =====================================================================
// Minimal Windows type declarations
// =====================================================================

alias BOOL      = int;
alias BYTE      = ubyte;
alias WORD      = ushort;
alias DWORD     = uint;
alias UINT      = uint;
alias UINT32    = uint;
alias ULONG     = uint;
alias LONG      = int;
alias INT_PTR   = long;
alias LONG_PTR  = long;
alias ULONG_PTR = ulong;
alias WPARAM    = ulong;
alias LPARAM    = long;
alias LRESULT   = long;
alias HRESULT   = int;
alias HSTRING   = void*;
alias HWND      = void*;
alias HINSTANCE = void*;
alias HMODULE   = void*;
alias HBRUSH    = void*;
alias HCURSOR   = void*;
alias HICON     = void*;
alias HMENU     = void*;
alias ATOM      = ushort;

alias TrustLevel = int;

enum BOOL TRUE  = 1;
enum BOOL FALSE = 0;

enum int S_OK               = 0;
enum int S_FALSE            = 1;
enum int E_INVALIDARG       = cast(int)0x80070057;
enum int RPC_E_CHANGED_MODE = cast(int)0x80010106;

bool SUCCEEDED(int hr) { return hr >= 0; }
bool FAILED(int hr)    { return hr < 0; }

HRESULT HRESULT_FROM_WIN32(DWORD x)
{
    return (x <= 0) ? cast(HRESULT)x : cast(HRESULT)((x & 0x0000FFFF) | 0x80070000);
}

struct GUID
{
    DWORD  Data1;
    WORD   Data2;
    WORD   Data3;
    BYTE[8] Data4;
}

alias IID = GUID;

struct RECT  { LONG left, top, right, bottom; }
struct POINT { LONG x, y; }
struct MSG   { HWND hwnd; UINT message; WPARAM wParam; LPARAM lParam; DWORD time; POINT pt; }

alias WNDPROC = extern(Windows) LRESULT function(HWND, UINT, WPARAM, LPARAM) nothrow;

struct WNDCLASSEXW
{
    UINT      cbSize;
    UINT      style;
    WNDPROC   lpfnWndProc;
    int       cbClsExtra;
    int       cbWndExtra;
    HINSTANCE hInstance;
    HICON     hIcon;
    HCURSOR   hCursor;
    HBRUSH    hbrBackground;
    const(wchar)* lpszMenuName;
    const(wchar)* lpszClassName;
    HICON     hIconSm;
}

// Window styles / constants
enum : UINT
{
    WS_OVERLAPPED       = 0x00000000,
    WS_CAPTION          = 0x00C00000,
    WS_SYSMENU          = 0x00080000,
    WS_THICKFRAME       = 0x00040000,
    WS_MINIMIZEBOX      = 0x00020000,
    WS_MAXIMIZEBOX      = 0x00010000,
    WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX,

    WM_CREATE  = 0x0001,
    WM_DESTROY = 0x0002,
    WM_SIZE    = 0x0005,

    CW_USEDEFAULT = cast(UINT)0x80000000,

    SW_SHOW = 5,

    CS_HREDRAW = 0x0002,
    CS_VREDRAW = 0x0001,

    COLOR_WINDOW = 5,

    IDC_ARROW = cast(UINT)32512,

    ERROR_CLASS_ALREADY_EXISTS = 1410,
}

// Windows API declarations
extern(Windows) nothrow
{
    ATOM    RegisterClassExW(const(WNDCLASSEXW)*);
    HWND    CreateWindowExW(DWORD, const(wchar)*, const(wchar)*, DWORD, int, int, int, int, HWND, HMENU, HINSTANCE, void*);
    LRESULT DefWindowProcW(HWND, UINT, WPARAM, LPARAM);
    BOOL    ShowWindow(HWND, int);
    BOOL    UpdateWindow(HWND);
    BOOL    GetClientRect(HWND, RECT*);
    int     GetMessageW(MSG*, HWND, UINT, UINT);
    BOOL    TranslateMessage(const(MSG)*);
    LRESULT DispatchMessageW(const(MSG)*);
    void    PostQuitMessage(int);
    BOOL    AdjustWindowRect(RECT*, DWORD, BOOL);
    int     MessageBoxW(HWND, const(wchar)*, const(wchar)*, UINT);
    HCURSOR LoadCursorW(HINSTANCE, const(wchar)*);
    void    OutputDebugStringA(const(char)*);

    HMODULE GetModuleHandleW(const(wchar)*);
    HMODULE LoadLibraryW(const(wchar)*);

    // GetProcAddress returns a generic function pointer in D
    void* GetProcAddress(HMODULE, const(char)*);

    DWORD GetLastError();
}

// COM / WinRT API declarations
extern(Windows) nothrow
{
    HRESULT CoInitializeEx(void*, DWORD);
    void    CoUninitialize();
    HRESULT RoInitialize(uint);
    void    RoUninitialize();
    HRESULT WindowsCreateString(const(wchar)*, UINT32, HSTRING*);
    HRESULT WindowsDeleteString(HSTRING);
    HRESULT RoGetActivationFactory(HSTRING, const(GUID)*, void**);
    HRESULT RoActivateInstance(HSTRING, void**);
}

enum : DWORD { COINIT_APARTMENTTHREADED = 0x2 }
enum : uint  { RO_INIT_SINGLETHREADED  = 0   }

// =====================================================================
// DispatcherQueue interop types
// =====================================================================

enum DISPATCHERQUEUE_THREAD_TYPE : DWORD
{
    DQTYPE_THREAD_DEDICATED = 1,
    DQTYPE_THREAD_CURRENT   = 2,
}

enum DISPATCHERQUEUE_THREAD_APARTMENTTYPE : DWORD
{
    DQTAT_COM_NONE = 0,
    DQTAT_COM_ASTA = 1,
    DQTAT_COM_STA  = 2,
}

struct DispatcherQueueOptions
{
    DWORD dwSize;
    DISPATCHERQUEUE_THREAD_TYPE threadType;
    DISPATCHERQUEUE_THREAD_APARTMENTTYPE apartmentType;
}

extern(Windows) nothrow
HRESULT CreateDispatcherQueueController(
    DispatcherQueueOptions options, void** dispatcherQueueController);

// =====================================================================
// C-compatible COM interface structs (vtable-based)
// =====================================================================

struct Microsoft_UI_WindowId { ulong Value; }
struct EventRegistrationToken { long value; }

alias PfnWindowing_GetWindowIdFromWindow =
    extern(Windows) nothrow HRESULT function(HWND, Microsoft_UI_WindowId*);

// IUnknown (C-layout struct for raw COM vtable access)
struct IUnknownC
{
    IUnknownCVtbl* lpVtbl;
}

struct IUnknownCVtbl
{
    extern(Windows) nothrow HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) nothrow ULONG   function(void*) AddRef;
    extern(Windows) nothrow ULONG   function(void*) Release;
}

// IInspectable
struct IInspectable
{
    IInspectableVtbl* lpVtbl;
}

struct IInspectableVtbl
{
    // IUnknown
    extern(Windows) nothrow HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) nothrow ULONG   function(void*) AddRef;
    extern(Windows) nothrow ULONG   function(void*) Release;
    // IInspectable
    extern(Windows) nothrow HRESULT function(void*, ULONG*, GUID**) GetIids;
    extern(Windows) nothrow HRESULT function(void*, HSTRING*) GetRuntimeClassName;
    extern(Windows) nothrow HRESULT function(void*, TrustLevel*) GetTrustLevel;
}

// IWindowsXamlManagerStatics
struct IWindowsXamlManagerStatics
{
    IWindowsXamlManagerStaticsVtbl* lpVtbl;
}

struct IWindowsXamlManagerStaticsVtbl
{
    extern(Windows) nothrow HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) nothrow ULONG   function(void*) AddRef;
    extern(Windows) nothrow ULONG   function(void*) Release;
    extern(Windows) nothrow HRESULT function(void*, ULONG*, GUID**) GetIids;
    extern(Windows) nothrow HRESULT function(void*, HSTRING*) GetRuntimeClassName;
    extern(Windows) nothrow HRESULT function(void*, TrustLevel*) GetTrustLevel;
    extern(Windows) nothrow HRESULT function(void*, IInspectable**) InitializeForCurrentThread;
}

// IDesktopWindowXamlSource
struct IDesktopWindowXamlSource
{
    IDesktopWindowXamlSourceVtbl* lpVtbl;
}

struct IDesktopWindowXamlSourceVtbl
{
    extern(Windows) nothrow HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) nothrow ULONG   function(void*) AddRef;
    extern(Windows) nothrow ULONG   function(void*) Release;
    extern(Windows) nothrow HRESULT function(void*, ULONG*, GUID**) GetIids;
    extern(Windows) nothrow HRESULT function(void*, HSTRING*) GetRuntimeClassName;
    extern(Windows) nothrow HRESULT function(void*, TrustLevel*) GetTrustLevel;
    extern(Windows) nothrow HRESULT function(void*, IInspectable**) get_Content;
    extern(Windows) nothrow HRESULT function(void*, IInspectable*) put_Content;
    extern(Windows) nothrow HRESULT function(void*, int*) get_HasFocus;
    extern(Windows) nothrow HRESULT function(void*, IInspectable**) get_SystemBackdrop;
    extern(Windows) nothrow HRESULT function(void*, IInspectable*) put_SystemBackdrop;
    extern(Windows) nothrow HRESULT function(void*, IInspectable**) get_SiteBridge;
    extern(Windows) nothrow HRESULT function(void*, void*, EventRegistrationToken*) add_TakeFocusRequested;
    extern(Windows) nothrow HRESULT function(void*, EventRegistrationToken) remove_TakeFocusRequested;
    extern(Windows) nothrow HRESULT function(void*, void*, EventRegistrationToken*) add_GotFocus;
    extern(Windows) nothrow HRESULT function(void*, EventRegistrationToken) remove_GotFocus;
    extern(Windows) nothrow HRESULT function(void*, IInspectable*, IInspectable**) NavigateFocus;
    extern(Windows) nothrow HRESULT function(void*, Microsoft_UI_WindowId) Initialize;
}

// IXamlReaderStatics
struct IXamlReaderStatics
{
    IXamlReaderStaticsVtbl* lpVtbl;
}

struct IXamlReaderStaticsVtbl
{
    extern(Windows) nothrow HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) nothrow ULONG   function(void*) AddRef;
    extern(Windows) nothrow ULONG   function(void*) Release;
    extern(Windows) nothrow HRESULT function(void*, ULONG*, GUID**) GetIids;
    extern(Windows) nothrow HRESULT function(void*, HSTRING*) GetRuntimeClassName;
    extern(Windows) nothrow HRESULT function(void*, TrustLevel*) GetTrustLevel;
    extern(Windows) nothrow HRESULT function(void*, HSTRING, IInspectable**) Load;
    extern(Windows) nothrow HRESULT function(void*, HSTRING, IInspectable**) LoadWithInitialTemplateValidation;
}

// IDispatcherQueueControllerStatics
struct IDispatcherQueueControllerStatics
{
    IDispatcherQueueControllerStaticsVtbl* lpVtbl;
}

struct IDispatcherQueueControllerStaticsVtbl
{
    extern(Windows) nothrow HRESULT function(void*, const(GUID)*, void**) QueryInterface;
    extern(Windows) nothrow ULONG   function(void*) AddRef;
    extern(Windows) nothrow ULONG   function(void*) Release;
    extern(Windows) nothrow HRESULT function(void*, ULONG*, GUID**) GetIids;
    extern(Windows) nothrow HRESULT function(void*, HSTRING*) GetRuntimeClassName;
    extern(Windows) nothrow HRESULT function(void*, TrustLevel*) GetTrustLevel;
    extern(Windows) nothrow HRESULT function(void*, IInspectable**) CreateOnDedicatedThread;
    extern(Windows) nothrow HRESULT function(void*, IInspectable**) CreateOnCurrentThread;
}

// =====================================================================
// Interface GUIDs
// =====================================================================

immutable GUID IID_IWindowsXamlManagerStatics =
    GUID(0x56CB591D, 0xDE97, 0x539F, [0x88, 0x1D, 0x8C, 0xCD, 0xC4, 0x4F, 0xA6, 0xC4]);
immutable GUID IID_IDesktopWindowXamlSource =
    GUID(0x553AF92C, 0x1381, 0x51D6, [0xBE, 0xE0, 0xF3, 0x4B, 0xEB, 0x04, 0x2E, 0xA8]);
immutable GUID IID_IXamlReaderStatics =
    GUID(0x82A4CD9E, 0x435E, 0x5AEB, [0x8C, 0x4F, 0x30, 0x0C, 0xEC, 0xE4, 0x5C, 0xAE]);
immutable GUID IID_IUIElement =
    GUID(0xC3C01020, 0x320C, 0x5CF6, [0x9D, 0x24, 0xD3, 0x96, 0xBB, 0xFA, 0x4D, 0x8B]);
immutable GUID IID_IDispatcherQueueControllerStatics =
    GUID(0xF18D6145, 0x722B, 0x593D, [0xBC, 0xF2, 0xA6, 0x1E, 0x71, 0x3F, 0x00, 0x37]);

// =====================================================================
// MddBootstrap helper (from mdd_helper.c)
// =====================================================================

extern(Windows) nothrow
{
    HRESULT MddBootstrapInitialize2(UINT32 majorMinorVersion, const(wchar)* versionTag, ulong minVersion, DWORD options);
    void    MddBootstrapShutdown();
}

extern(C) nothrow HRESULT MddBootstrapInit()
{
    enum UINT32 WINDOWSAPPSDK_RELEASE_MAJORMINOR = 0x00010008;
    enum ulong  WINDOWSAPPSDK_RUNTIME_VERSION_UINT64 = 0x1F40030203B30000UL;
    enum DWORD  MddBootstrapInitializeOptions_None = 0;
    return MddBootstrapInitialize2(
        WINDOWSAPPSDK_RELEASE_MAJORMINOR,
        null,
        WINDOWSAPPSDK_RUNTIME_VERSION_UINT64,
        MddBootstrapInitializeOptions_None);
}

extern(C) nothrow void MddBootstrapDeinit()
{
    MddBootstrapShutdown();
}

// =====================================================================
// Global state
// =====================================================================

__gshared HWND g_mainWindow = null;
__gshared IInspectable* g_dispatcherQueueController = null;
__gshared void* g_coreDispatcherQueueController = null;
__gshared IInspectable* g_windowsXamlManager = null;
__gshared IInspectable* g_desktopWindowXamlSourceInspectable = null;
__gshared IDesktopWindowXamlSource* g_desktopWindowXamlSource = null;

// =====================================================================
// Utility functions
// =====================================================================

void LogState(const(char)* functionName, const(char)* fmt, ...)
{
    char[768] body_ = 0;
    char[1024] line = 0;

    va_list args;
    va_start(args, fmt);
    vsnprintf(body_.ptr, body_.length, fmt, args);
    va_end(args);

    snprintf(line.ptr, line.length, "[%s] %s\n", functionName, body_.ptr);
    OutputDebugStringA(line.ptr);
}

void ReleaseIf(void** pp)
{
    if (pp && *pp)
    {
        auto unk = cast(IUnknownC*)(*pp);
        unk.lpVtbl.Release(cast(void*)unk);
        *pp = null;
    }
}

HRESULT CreateHStringFromLiteral(const(wchar)* text, HSTRING* hstr)
{
    if (!text || !hstr) return E_INVALIDARG;

    UINT32 len = 0;
    const(wchar)* p = text;
    while (*p) { len++; p++; }

    return WindowsCreateString(text, len, hstr);
}

// =====================================================================
// DispatcherQueue initialization
// =====================================================================

HRESULT EnsureDispatcherQueue()
{
    enum FN = "EnsureDispatcherQueue";
    HRESULT hr;
    HSTRING className = null;

    if (g_dispatcherQueueController && g_coreDispatcherQueueController)
    {
        LogState(FN, "already initialized");
        return S_OK;
    }

    // Try WinUI3 DispatcherQueueController.CreateOnCurrentThread
    hr = CreateHStringFromLiteral("Microsoft.UI.Dispatching.DispatcherQueueController"w.ptr, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString failed hr=0x%08X", cast(uint)hr);
        return hr;
    }

    if (!g_dispatcherQueueController)
    {
        IDispatcherQueueControllerStatics* statics = null;
        hr = RoGetActivationFactory(className, &IID_IDispatcherQueueControllerStatics, cast(void**)&statics);
        LogState(FN, "RoGetActivationFactory(DispatcherQueueController) hr=0x%08X", cast(uint)hr);
        if (SUCCEEDED(hr))
        {
            hr = statics.lpVtbl.CreateOnCurrentThread(cast(void*)statics, &g_dispatcherQueueController);
            LogState(FN, "CreateOnCurrentThread hr=0x%08X controller=0x%p",
                cast(uint)hr, cast(void*)g_dispatcherQueueController);
        }
        ReleaseIf(cast(void**)&statics);
    }

    // Fallback to CoreMessaging
    if (!g_coreDispatcherQueueController)
    {
        DispatcherQueueOptions options;
        options.dwSize = DispatcherQueueOptions.sizeof;
        options.threadType = DISPATCHERQUEUE_THREAD_TYPE.DQTYPE_THREAD_CURRENT;
        options.apartmentType = DISPATCHERQUEUE_THREAD_APARTMENTTYPE.DQTAT_COM_NONE;
        HRESULT hrCore = CreateDispatcherQueueController(options, &g_coreDispatcherQueueController);
        LogState(FN, "CoreMessaging CreateDispatcherQueueController hr=0x%08X controller=0x%p",
            cast(uint)hrCore, g_coreDispatcherQueueController);
        if (FAILED(hrCore) && !g_dispatcherQueueController)
            hr = hrCore;
    }

    if (className) WindowsDeleteString(className);
    return (g_dispatcherQueueController || g_coreDispatcherQueueController) ? S_OK : hr;
}

// =====================================================================
// WindowId resolution
// =====================================================================

HRESULT GetWindowIdForHwnd(HWND hwnd, Microsoft_UI_WindowId* windowId)
{
    enum FN = "GetWindowIdForHwnd";

    if (!windowId) return E_INVALIDARG;
    *windowId = Microsoft_UI_WindowId(0);

    HMODULE frameworkUdk = GetModuleHandleW("Microsoft.Internal.FrameworkUdk.dll"w.ptr);
    if (!frameworkUdk)
        frameworkUdk = LoadLibraryW("Microsoft.Internal.FrameworkUdk.dll"w.ptr);
    if (!frameworkUdk)
    {
        HRESULT hr = HRESULT_FROM_WIN32(GetLastError());
        LogState(FN, "LoadLibraryW failed hr=0x%08X", cast(uint)hr);
        return hr;
    }

    auto proc = cast(PfnWindowing_GetWindowIdFromWindow)
        GetProcAddress(frameworkUdk, "Windowing_GetWindowIdFromWindow");
    if (!proc)
    {
        HRESULT hr = HRESULT_FROM_WIN32(GetLastError());
        LogState(FN, "GetProcAddress failed hr=0x%08X", cast(uint)hr);
        return hr;
    }

    HRESULT hr = proc(hwnd, windowId);
    LogState(FN, "Windowing_GetWindowIdFromWindow hr=0x%08X value=%llu",
        cast(uint)hr, windowId.Value);
    return hr;
}

// =====================================================================
// XAML content loading
// =====================================================================

HRESULT LoadTriangleXaml()
{
    enum FN = "LoadTriangleXaml";
    HRESULT hr;
    HSTRING className = null;
    HSTRING xamlText = null;
    IXamlReaderStatics* xamlReaderStatics = null;
    IInspectable* rootObject = null;
    IInspectable* rootElement = null;

    // Triangle XAML markup
    static immutable wstring kTriangleXaml =
        "<Canvas xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "w ~
        "xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Background='White'>"w ~
        "<Path Stroke='Black' StrokeThickness='1'>"w ~
        "<Path.Fill>"w ~
        "<LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>"w ~
        "<GradientStop Color='Red' Offset='0'/>"w ~
        "<GradientStop Color='Green' Offset='0.5'/>"w ~
        "<GradientStop Color='Blue' Offset='1'/>"w ~
        "</LinearGradientBrush>"w ~
        "</Path.Fill>"w ~
        "<Path.Data>"w ~
        "<PathGeometry>"w ~
        "<PathFigure StartPoint='300,100' IsClosed='True'>"w ~
        "<LineSegment Point='500,400'/>"w ~
        "<LineSegment Point='100,400'/>"w ~
        "</PathFigure>"w ~
        "</PathGeometry>"w ~
        "</Path.Data>"w ~
        "</Path>"w ~
        "</Canvas>"w;

    hr = CreateHStringFromLiteral("Microsoft.UI.Xaml.Markup.XamlReader"w.ptr, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(class) failed hr=0x%08X", cast(uint)hr);
        goto cleanup;
    }

    hr = RoGetActivationFactory(className, &IID_IXamlReaderStatics, cast(void**)&xamlReaderStatics);
    LogState(FN, "RoGetActivationFactory(XamlReader) hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) goto cleanup;

    hr = CreateHStringFromLiteral(kTriangleXaml.ptr, &xamlText);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(xaml) failed hr=0x%08X", cast(uint)hr);
        goto cleanup;
    }

    hr = xamlReaderStatics.lpVtbl.Load(cast(void*)xamlReaderStatics, xamlText, &rootObject);
    LogState(FN, "IXamlReaderStatics::Load hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) goto cleanup;

    hr = rootObject.lpVtbl.QueryInterface(cast(void*)rootObject, &IID_IUIElement, cast(void**)&rootElement);
    LogState(FN, "QI(IUIElement) hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) goto cleanup;

    hr = g_desktopWindowXamlSource.lpVtbl.put_Content(
        cast(void*)g_desktopWindowXamlSource, rootElement);
    LogState(FN, "IDesktopWindowXamlSource::put_Content hr=0x%08X", cast(uint)hr);

cleanup:
    ReleaseIf(cast(void**)&rootElement);
    ReleaseIf(cast(void**)&rootObject);
    ReleaseIf(cast(void**)&xamlReaderStatics);
    if (xamlText)  WindowsDeleteString(xamlText);
    if (className) WindowsDeleteString(className);
    return hr;
}

// =====================================================================
// XAML Island initialization
// =====================================================================

HRESULT InitializeXamlIsland(HWND parentWindow)
{
    enum FN = "InitializeXamlIsland";
    HRESULT hr;
    HSTRING className = null;
    IWindowsXamlManagerStatics* xamlManagerStatics = null;

    hr = EnsureDispatcherQueue();
    if (FAILED(hr)) return hr;

    // Initialize WindowsXamlManager
    hr = CreateHStringFromLiteral(
        "Microsoft.UI.Xaml.Hosting.WindowsXamlManager"w.ptr, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(WindowsXamlManager) failed hr=0x%08X", cast(uint)hr);
        return hr;
    }

    hr = RoGetActivationFactory(className, &IID_IWindowsXamlManagerStatics,
        cast(void**)&xamlManagerStatics);
    LogState(FN, "RoGetActivationFactory(WindowsXamlManager) hr=0x%08X", cast(uint)hr);
    if (FAILED(hr))
    {
        WindowsDeleteString(className);
        return hr;
    }

    hr = xamlManagerStatics.lpVtbl.InitializeForCurrentThread(
        cast(void*)xamlManagerStatics, &g_windowsXamlManager);
    LogState(FN, "InitializeForCurrentThread hr=0x%08X", cast(uint)hr);
    if (FAILED(hr))
    {
        HRESULT hrRetry = EnsureDispatcherQueue();
        LogState(FN, "EnsureDispatcherQueue(retry) hr=0x%08X", cast(uint)hrRetry);
        if (SUCCEEDED(hrRetry))
        {
            hr = xamlManagerStatics.lpVtbl.InitializeForCurrentThread(
                cast(void*)xamlManagerStatics, &g_windowsXamlManager);
            LogState(FN, "InitializeForCurrentThread retry hr=0x%08X", cast(uint)hr);
        }
    }
    if (FAILED(hr))
        LogState(FN, "InitializeForCurrentThread failed; continuing with DesktopWindowXamlSource fallback");

    ReleaseIf(cast(void**)&xamlManagerStatics);
    WindowsDeleteString(className);

    // Create DesktopWindowXamlSource
    hr = CreateHStringFromLiteral(
        "Microsoft.UI.Xaml.Hosting.DesktopWindowXamlSource"w.ptr, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(DesktopWindowXamlSource) failed hr=0x%08X", cast(uint)hr);
        return hr;
    }

    hr = RoActivateInstance(className, cast(void**)&g_desktopWindowXamlSourceInspectable);
    LogState(FN, "RoActivateInstance(DesktopWindowXamlSource) hr=0x%08X", cast(uint)hr);
    WindowsDeleteString(className);
    if (FAILED(hr)) return hr;

    hr = g_desktopWindowXamlSourceInspectable.lpVtbl.QueryInterface(
        cast(void*)g_desktopWindowXamlSourceInspectable,
        &IID_IDesktopWindowXamlSource,
        cast(void**)&g_desktopWindowXamlSource);
    LogState(FN, "QI(IDesktopWindowXamlSource) hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) return hr;

    // Initialize with parent window
    Microsoft_UI_WindowId windowId;
    hr = GetWindowIdForHwnd(parentWindow, &windowId);
    if (FAILED(hr)) return hr;

    hr = g_desktopWindowXamlSource.lpVtbl.Initialize(
        cast(void*)g_desktopWindowXamlSource, windowId);
    LogState(FN, "IDesktopWindowXamlSource::Initialize hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) return hr;

    return LoadTriangleXaml();
}

void CleanupXamlIsland()
{
    LogState("CleanupXamlIsland", "begin");
    ReleaseIf(cast(void**)&g_desktopWindowXamlSource);
    ReleaseIf(cast(void**)&g_desktopWindowXamlSourceInspectable);
    ReleaseIf(cast(void**)&g_windowsXamlManager);
    ReleaseIf(&g_coreDispatcherQueueController);
    ReleaseIf(cast(void**)&g_dispatcherQueueController);
    LogState("CleanupXamlIsland", "end");
}

// =====================================================================
// Window procedure and creation
// =====================================================================

extern(Windows) LRESULT WindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
{
    switch (message)
    {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(hwnd, message, wParam, lParam);
    }
}

HRESULT CreateMainWindow(HINSTANCE instance)
{
    enum FN = "CreateMainWindow";

    WNDCLASSEXW wc;
    memset(&wc, 0, wc.sizeof);
    wc.cbSize        = WNDCLASSEXW.sizeof;
    wc.hInstance     = instance;
    wc.lpszClassName = "HelloWinUI3DWindow"w.ptr;
    wc.lpfnWndProc   = &WindowProc;
    wc.hCursor       = LoadCursorW(null, cast(const(wchar)*)cast(size_t)IDC_ARROW);
    wc.hbrBackground = cast(HBRUSH)(cast(LONG_PTR)(COLOR_WINDOW + 1));

    if (!RegisterClassExW(&wc))
    {
        DWORD gle = GetLastError();
        if (gle != ERROR_CLASS_ALREADY_EXISTS)
        {
            LogState(FN, "RegisterClassExW failed gle=%lu", gle);
            return HRESULT_FROM_WIN32(gle);
        }
    }

    RECT rc = RECT(0, 0, 960, 540);
    DWORD style = WS_OVERLAPPEDWINDOW;
    AdjustWindowRect(&rc, style, FALSE);

    g_mainWindow = CreateWindowExW(
        0,
        "HelloWinUI3DWindow"w.ptr,
        "Hello, World!"w.ptr,
        style,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rc.right - rc.left, rc.bottom - rc.top,
        null, null, instance, null);

    if (!g_mainWindow)
    {
        DWORD gle = GetLastError();
        LogState(FN, "CreateWindowExW failed gle=%lu", gle);
        return HRESULT_FROM_WIN32(gle);
    }

    ShowWindow(g_mainWindow, SW_SHOW);
    UpdateWindow(g_mainWindow);
    LogState(FN, "window created hwnd=0x%p", cast(void*)g_mainWindow);
    return S_OK;
}

// =====================================================================
// Entry point
// =====================================================================

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, char* lpCmdLine, int nCmdShow)
{
    enum FN = "WinMain";
    HRESULT hr;
    bool bootstrapInitialized = false;
    bool apartmentInitialized = false;
    bool roInitialized = false;
    int exitCode = 0;

    LogState(FN, "begin");

    // Initialize Windows App SDK bootstrap (via C helper)
    hr = MddBootstrapInit();
    LogState(FN, "MddBootstrapInit hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) { exitCode = 1; goto cleanup; }
    bootstrapInitialized = true;

    // Initialize COM apartment
    hr = CoInitializeEx(null, COINIT_APARTMENTTHREADED);
    LogState(FN, "CoInitializeEx hr=0x%08X", cast(uint)hr);
    if (SUCCEEDED(hr))
        apartmentInitialized = true;
    else if (hr != RPC_E_CHANGED_MODE)
    { exitCode = 1; goto cleanup; }

    // Initialize WinRT
    hr = RoInitialize(RO_INIT_SINGLETHREADED);
    LogState(FN, "RoInitialize hr=0x%08X", cast(uint)hr);
    if (SUCCEEDED(hr) || hr == S_FALSE)
        roInitialized = true;
    else if (hr != RPC_E_CHANGED_MODE)
    { exitCode = 1; goto cleanup; }

    // Create dispatcher queue
    hr = EnsureDispatcherQueue();
    LogState(FN, "EnsureDispatcherQueue hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) { exitCode = 1; goto cleanup; }

    // Create main window
    hr = CreateMainWindow(hInstance);
    if (FAILED(hr)) { exitCode = 1; goto cleanup; }

    // Initialize XAML island
    hr = InitializeXamlIsland(g_mainWindow);
    LogState(FN, "InitializeXamlIsland hr=0x%08X", cast(uint)hr);
    if (FAILED(hr)) { exitCode = 1; goto cleanup; }

    // Message loop
    {
        MSG msg;
        while (GetMessageW(&msg, null, 0, 0) > 0)
        {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }

cleanup:
    CleanupXamlIsland();

    if (roInitialized)
    {
        RoUninitialize();
        LogState(FN, "RoUninitialize");
    }
    if (apartmentInitialized)
    {
        CoUninitialize();
        LogState(FN, "CoUninitialize");
    }
    if (bootstrapInitialized)
    {
        MddBootstrapDeinit();
        LogState(FN, "MddBootstrapShutdown");
    }

    LogState(FN, "end exitCode=%d", exitCode);
    return exitCode;
}
