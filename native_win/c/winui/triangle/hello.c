#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <roapi.h>
#include <inspectable.h>
#include <winstring.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdbool.h>
#include <wchar.h>

#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "runtimeobject.lib")
#pragma comment(lib, "windowsapp.lib")
#pragma comment(lib, "CoreMessaging.lib")

/* C-compatible CoreMessaging dispatcher queue declarations. */
typedef enum DISPATCHERQUEUE_THREAD_TYPE {
    DQTYPE_THREAD_DEDICATED = 1,
    DQTYPE_THREAD_CURRENT = 2
} DISPATCHERQUEUE_THREAD_TYPE;

typedef enum DISPATCHERQUEUE_THREAD_APARTMENTTYPE {
    DQTAT_COM_NONE = 0,
    DQTAT_COM_ASTA = 1,
    DQTAT_COM_STA = 2
} DISPATCHERQUEUE_THREAD_APARTMENTTYPE;

typedef struct DispatcherQueueOptions {
    DWORD dwSize;
    DISPATCHERQUEUE_THREAD_TYPE threadType;
    DISPATCHERQUEUE_THREAD_APARTMENTTYPE apartmentType;
} DispatcherQueueOptions;

STDAPI CreateDispatcherQueueController(
    DispatcherQueueOptions options,
    IUnknown** dispatcherQueueController);

/* Minimal WinRT interface definitions used by this sample. */
typedef struct IWindowsXamlManagerStatics IWindowsXamlManagerStatics;
typedef struct IDesktopWindowXamlSource IDesktopWindowXamlSource;
typedef struct IXamlReaderStatics IXamlReaderStatics;
typedef struct IDispatcherQueueControllerStatics IDispatcherQueueControllerStatics;

typedef struct Microsoft_UI_WindowId
{
    unsigned long long Value;
} Microsoft_UI_WindowId;

typedef struct EventRegistrationToken
{
    long long value;
} EventRegistrationToken;

typedef HRESULT(STDAPICALLTYPE* PfnWindowing_GetWindowIdFromWindow)(HWND hwnd, Microsoft_UI_WindowId* windowId);

typedef struct IWindowsXamlManagerStaticsVtbl {
    HRESULT(STDMETHODCALLTYPE* QueryInterface)(IWindowsXamlManagerStatics* This, REFIID riid, void** ppvObject);
    ULONG(STDMETHODCALLTYPE* AddRef)(IWindowsXamlManagerStatics* This);
    ULONG(STDMETHODCALLTYPE* Release)(IWindowsXamlManagerStatics* This);
    HRESULT(STDMETHODCALLTYPE* GetIids)(IWindowsXamlManagerStatics* This, ULONG* iidCount, IID** iids);
    HRESULT(STDMETHODCALLTYPE* GetRuntimeClassName)(IWindowsXamlManagerStatics* This, HSTRING* className);
    HRESULT(STDMETHODCALLTYPE* GetTrustLevel)(IWindowsXamlManagerStatics* This, TrustLevel* trustLevel);
    HRESULT(STDMETHODCALLTYPE* InitializeForCurrentThread)(IWindowsXamlManagerStatics* This, IInspectable** value);
} IWindowsXamlManagerStaticsVtbl;

struct IWindowsXamlManagerStatics {
    const IWindowsXamlManagerStaticsVtbl* lpVtbl;
};

typedef struct IDesktopWindowXamlSourceVtbl {
    HRESULT(STDMETHODCALLTYPE* QueryInterface)(IDesktopWindowXamlSource* This, REFIID riid, void** ppvObject);
    ULONG(STDMETHODCALLTYPE* AddRef)(IDesktopWindowXamlSource* This);
    ULONG(STDMETHODCALLTYPE* Release)(IDesktopWindowXamlSource* This);
    HRESULT(STDMETHODCALLTYPE* GetIids)(IDesktopWindowXamlSource* This, ULONG* iidCount, IID** iids);
    HRESULT(STDMETHODCALLTYPE* GetRuntimeClassName)(IDesktopWindowXamlSource* This, HSTRING* className);
    HRESULT(STDMETHODCALLTYPE* GetTrustLevel)(IDesktopWindowXamlSource* This, TrustLevel* trustLevel);
    HRESULT(STDMETHODCALLTYPE* get_Content)(IDesktopWindowXamlSource* This, IInspectable** value);
    HRESULT(STDMETHODCALLTYPE* put_Content)(IDesktopWindowXamlSource* This, IInspectable* value);
    HRESULT(STDMETHODCALLTYPE* get_HasFocus)(IDesktopWindowXamlSource* This, boolean* value);
    HRESULT(STDMETHODCALLTYPE* get_SystemBackdrop)(IDesktopWindowXamlSource* This, IInspectable** value);
    HRESULT(STDMETHODCALLTYPE* put_SystemBackdrop)(IDesktopWindowXamlSource* This, IInspectable* value);
    HRESULT(STDMETHODCALLTYPE* get_SiteBridge)(IDesktopWindowXamlSource* This, IInspectable** value);
    HRESULT(STDMETHODCALLTYPE* add_TakeFocusRequested)(IDesktopWindowXamlSource* This, IUnknown* handler, EventRegistrationToken* token);
    HRESULT(STDMETHODCALLTYPE* remove_TakeFocusRequested)(IDesktopWindowXamlSource* This, EventRegistrationToken token);
    HRESULT(STDMETHODCALLTYPE* add_GotFocus)(IDesktopWindowXamlSource* This, IUnknown* handler, EventRegistrationToken* token);
    HRESULT(STDMETHODCALLTYPE* remove_GotFocus)(IDesktopWindowXamlSource* This, EventRegistrationToken token);
    HRESULT(STDMETHODCALLTYPE* NavigateFocus)(IDesktopWindowXamlSource* This, IInspectable* request, IInspectable** result);
    HRESULT(STDMETHODCALLTYPE* Initialize)(IDesktopWindowXamlSource* This, Microsoft_UI_WindowId parentWindowId);
} IDesktopWindowXamlSourceVtbl;

struct IDesktopWindowXamlSource {
    const IDesktopWindowXamlSourceVtbl* lpVtbl;
};

typedef struct IXamlReaderStaticsVtbl {
    HRESULT(STDMETHODCALLTYPE* QueryInterface)(IXamlReaderStatics* This, REFIID riid, void** ppvObject);
    ULONG(STDMETHODCALLTYPE* AddRef)(IXamlReaderStatics* This);
    ULONG(STDMETHODCALLTYPE* Release)(IXamlReaderStatics* This);
    HRESULT(STDMETHODCALLTYPE* GetIids)(IXamlReaderStatics* This, ULONG* iidCount, IID** iids);
    HRESULT(STDMETHODCALLTYPE* GetRuntimeClassName)(IXamlReaderStatics* This, HSTRING* className);
    HRESULT(STDMETHODCALLTYPE* GetTrustLevel)(IXamlReaderStatics* This, TrustLevel* trustLevel);
    HRESULT(STDMETHODCALLTYPE* Load)(IXamlReaderStatics* This, HSTRING xaml, IInspectable** value);
    HRESULT(STDMETHODCALLTYPE* LoadWithInitialTemplateValidation)(IXamlReaderStatics* This, HSTRING xaml, IInspectable** value);
} IXamlReaderStaticsVtbl;

struct IXamlReaderStatics {
    const IXamlReaderStaticsVtbl* lpVtbl;
};

typedef struct IDispatcherQueueControllerStaticsVtbl {
    HRESULT(STDMETHODCALLTYPE* QueryInterface)(IDispatcherQueueControllerStatics* This, REFIID riid, void** ppvObject);
    ULONG(STDMETHODCALLTYPE* AddRef)(IDispatcherQueueControllerStatics* This);
    ULONG(STDMETHODCALLTYPE* Release)(IDispatcherQueueControllerStatics* This);
    HRESULT(STDMETHODCALLTYPE* GetIids)(IDispatcherQueueControllerStatics* This, ULONG* iidCount, IID** iids);
    HRESULT(STDMETHODCALLTYPE* GetRuntimeClassName)(IDispatcherQueueControllerStatics* This, HSTRING* className);
    HRESULT(STDMETHODCALLTYPE* GetTrustLevel)(IDispatcherQueueControllerStatics* This, TrustLevel* trustLevel);
    HRESULT(STDMETHODCALLTYPE* CreateOnDedicatedThread)(IDispatcherQueueControllerStatics* This, IInspectable** value);
    HRESULT(STDMETHODCALLTYPE* CreateOnCurrentThread)(IDispatcherQueueControllerStatics* This, IInspectable** value);
} IDispatcherQueueControllerStaticsVtbl;

struct IDispatcherQueueControllerStatics {
    const IDispatcherQueueControllerStaticsVtbl* lpVtbl;
};

static const IID IID_IWindowsXamlManagerStatics =
    { 0x56CB591D, 0xDE97, 0x539F, { 0x88, 0x1D, 0x8C, 0xCD, 0xC4, 0x4F, 0xA6, 0xC4 } };
static const IID IID_IDesktopWindowXamlSource =
    { 0x553AF92C, 0x1381, 0x51D6, { 0xBE, 0xE0, 0xF3, 0x4B, 0xEB, 0x04, 0x2E, 0xA8 } };
static const IID IID_IXamlReaderStatics =
    { 0x82A4CD9E, 0x435E, 0x5AEB, { 0x8C, 0x4F, 0x30, 0x0C, 0xEC, 0xE4, 0x5C, 0xAE } };
static const IID IID_IUIElement =
    { 0xC3C01020, 0x320C, 0x5CF6, { 0x9D, 0x24, 0xD3, 0x96, 0xBB, 0xFA, 0x4D, 0x8B } };
static const IID IID_IDispatcherQueueControllerStatics =
    { 0xF18D6145, 0x722B, 0x593D, { 0xBC, 0xF2, 0xA6, 0x1E, 0x71, 0x3F, 0x00, 0x37 } };

static HWND g_mainWindow = NULL;

static IInspectable* g_dispatcherQueueController = NULL;
static IUnknown* g_coreDispatcherQueueController = NULL;
static IInspectable* g_windowsXamlManager = NULL;
static IInspectable* g_desktopWindowXamlSourceInspectable = NULL;
static IDesktopWindowXamlSource* g_desktopWindowXamlSource = NULL;

static void LogState(const char* functionName, const char* format, ...)
{
    char body[1024] = { 0 };
    char line[1280] = { 0 };
    va_list args;

    va_start(args, format);
    vsnprintf(body, sizeof(body), format, args);
    va_end(args);

    snprintf(line, sizeof(line), "[%s] %s\n", functionName, body);
    OutputDebugStringA(line);
}

static void ReleaseIf(void** pp)
{
    if (pp && *pp)
    {
        ((IUnknown*)(*pp))->lpVtbl->Release((IUnknown*)(*pp));
        *pp = NULL;
    }
}

static HRESULT CreateHStringFromLiteral(const wchar_t* text, HSTRING* out)
{
    if (!text || !out)
    {
        return E_INVALIDARG;
    }
    return WindowsCreateString(text, (UINT32)wcslen(text), out);
}

static HRESULT EnsureDispatcherQueue(void)
{
    const char* FN = "EnsureDispatcherQueue";
    HRESULT hr;
    HSTRING className = NULL;
    IDispatcherQueueControllerStatics* statics = NULL;
    static const wchar_t* kClassName = L"Microsoft.UI.Dispatching.DispatcherQueueController";

    if (g_dispatcherQueueController && g_coreDispatcherQueueController)
    {
        LogState(FN, "already initialized");
        return S_OK;
    }

    hr = CreateHStringFromLiteral(kClassName, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString failed hr=0x%08X", (unsigned)hr);
        return hr;
    }

    if (!g_dispatcherQueueController)
    {
        hr = RoGetActivationFactory(className, &IID_IDispatcherQueueControllerStatics, (void**)&statics);
        LogState(FN, "RoGetActivationFactory(DispatcherQueueController) hr=0x%08X", (unsigned)hr);
        if (SUCCEEDED(hr))
        {
            hr = statics->lpVtbl->CreateOnCurrentThread(statics, &g_dispatcherQueueController);
            LogState(FN, "CreateOnCurrentThread hr=0x%08X controller=0x%p", (unsigned)hr, g_dispatcherQueueController);
        }
        ReleaseIf((void**)&statics);
    }

    if (!g_coreDispatcherQueueController)
    {
        DispatcherQueueOptions options;
        HRESULT hrCore;
        options.dwSize = sizeof(options);
        options.threadType = DQTYPE_THREAD_CURRENT;
        options.apartmentType = DQTAT_COM_NONE;
        hrCore = CreateDispatcherQueueController(options, &g_coreDispatcherQueueController);
        LogState(
            FN,
            "CoreMessaging CreateDispatcherQueueController hr=0x%08X controller=0x%p",
            (unsigned)hrCore,
            g_coreDispatcherQueueController);
        if (FAILED(hrCore) && !g_dispatcherQueueController)
        {
            hr = hrCore;
        }
    }

    if (className)
    {
        WindowsDeleteString(className);
    }
    return (g_dispatcherQueueController || g_coreDispatcherQueueController) ? S_OK : hr;
}

static HRESULT GetWindowIdForHwnd(HWND hwnd, Microsoft_UI_WindowId* windowId)
{
    const char* FN = "GetWindowIdForHwnd";
    HMODULE frameworkUdk = GetModuleHandleW(L"Microsoft.Internal.FrameworkUdk.dll");
    PfnWindowing_GetWindowIdFromWindow proc = NULL;
    HRESULT hr;

    if (!windowId)
    {
        return E_INVALIDARG;
    }
    ZeroMemory(windowId, sizeof(*windowId));

    if (!frameworkUdk)
    {
        frameworkUdk = LoadLibraryW(L"Microsoft.Internal.FrameworkUdk.dll");
    }
    if (!frameworkUdk)
    {
        hr = HRESULT_FROM_WIN32(GetLastError());
        LogState(FN, "LoadLibraryW failed hr=0x%08X", (unsigned)hr);
        return hr;
    }

    proc = (PfnWindowing_GetWindowIdFromWindow)GetProcAddress(frameworkUdk, "Windowing_GetWindowIdFromWindow");
    if (!proc)
    {
        hr = HRESULT_FROM_WIN32(GetLastError());
        LogState(FN, "GetProcAddress(Windowing_GetWindowIdFromWindow) failed hr=0x%08X", (unsigned)hr);
        return hr;
    }

    hr = proc(hwnd, windowId);
    LogState(FN, "Windowing_GetWindowIdFromWindow hr=0x%08X value=%llu", (unsigned)hr, windowId->Value);
    return hr;
}

static HRESULT LoadTriangleXaml(void)
{
    const char* FN = "LoadTriangleXaml";
    HRESULT hr;
    HSTRING className = NULL;
    HSTRING xamlText = NULL;
    IXamlReaderStatics* xamlReaderStatics = NULL;
    IInspectable* rootObject = NULL;
    IInspectable* rootElement = NULL;

    static const wchar_t* kXamlClass = L"Microsoft.UI.Xaml.Markup.XamlReader";
    static const wchar_t* kTriangleXaml =
        L"<Canvas xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "
        L"xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Background='White'>"
        L"<Path Stroke='Black' StrokeThickness='1'>"
        L"<Path.Fill>"
        L"<LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>"
        L"<GradientStop Color='Red' Offset='0'/>"
        L"<GradientStop Color='Green' Offset='0.5'/>"
        L"<GradientStop Color='Blue' Offset='1'/>"
        L"</LinearGradientBrush>"
        L"</Path.Fill>"
        L"<Path.Data>"
        L"<PathGeometry>"
        L"<PathFigure StartPoint='300,100' IsClosed='True'>"
        L"<LineSegment Point='500,400'/>"
        L"<LineSegment Point='100,400'/>"
        L"</PathFigure>"
        L"</PathGeometry>"
        L"</Path.Data>"
        L"</Path>"
        L"</Canvas>";

    hr = CreateHStringFromLiteral(kXamlClass, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(class) failed hr=0x%08X", (unsigned)hr);
        goto cleanup;
    }

    hr = RoGetActivationFactory(className, &IID_IXamlReaderStatics, (void**)&xamlReaderStatics);
    LogState(FN, "RoGetActivationFactory(XamlReader) hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        goto cleanup;
    }

    hr = CreateHStringFromLiteral(kTriangleXaml, &xamlText);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(xaml) failed hr=0x%08X", (unsigned)hr);
        goto cleanup;
    }

    hr = xamlReaderStatics->lpVtbl->Load(xamlReaderStatics, xamlText, &rootObject);
    LogState(FN, "IXamlReaderStatics::Load hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        goto cleanup;
    }

    hr = rootObject->lpVtbl->QueryInterface(rootObject, &IID_IUIElement, (void**)&rootElement);
    LogState(FN, "QI(IUIElement) hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        goto cleanup;
    }

    hr = g_desktopWindowXamlSource->lpVtbl->put_Content(g_desktopWindowXamlSource, rootElement);
    LogState(FN, "IDesktopWindowXamlSource::put_Content hr=0x%08X", (unsigned)hr);

cleanup:
    ReleaseIf((void**)&rootElement);
    ReleaseIf((void**)&rootObject);
    ReleaseIf((void**)&xamlReaderStatics);
    if (xamlText)
    {
        WindowsDeleteString(xamlText);
    }
    if (className)
    {
        WindowsDeleteString(className);
    }
    return hr;
}

static HRESULT InitializeXamlIsland(HWND parentWindow)
{
    const char* FN = "InitializeXamlIsland";
    HRESULT hr;
    HSTRING className = NULL;
    IWindowsXamlManagerStatics* xamlManagerStatics = NULL;

    static const wchar_t* kWindowsXamlManagerClass = L"Microsoft.UI.Xaml.Hosting.WindowsXamlManager";
    static const wchar_t* kDesktopWindowXamlSourceClass = L"Microsoft.UI.Xaml.Hosting.DesktopWindowXamlSource";

    hr = EnsureDispatcherQueue();
    if (FAILED(hr))
    {
        return hr;
    }

    hr = CreateHStringFromLiteral(kWindowsXamlManagerClass, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(WindowsXamlManager) failed hr=0x%08X", (unsigned)hr);
        return hr;
    }

    hr = RoGetActivationFactory(className, &IID_IWindowsXamlManagerStatics, (void**)&xamlManagerStatics);
    LogState(FN, "RoGetActivationFactory(WindowsXamlManager) hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        WindowsDeleteString(className);
        return hr;
    }

    hr = xamlManagerStatics->lpVtbl->InitializeForCurrentThread(xamlManagerStatics, &g_windowsXamlManager);
    LogState(FN, "InitializeForCurrentThread hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        HRESULT hrQueueRetry = EnsureDispatcherQueue();
        LogState(FN, "EnsureDispatcherQueue(retry) hr=0x%08X", (unsigned)hrQueueRetry);
        if (SUCCEEDED(hrQueueRetry))
        {
            hr = xamlManagerStatics->lpVtbl->InitializeForCurrentThread(xamlManagerStatics, &g_windowsXamlManager);
            LogState(FN, "InitializeForCurrentThread retry hr=0x%08X", (unsigned)hr);
        }
    }
    if (FAILED(hr))
    {
        LogState(FN, "InitializeForCurrentThread failed; continuing with DesktopWindowXamlSource fallback path");
    }
    ReleaseIf((void**)&xamlManagerStatics);
    WindowsDeleteString(className);

    hr = CreateHStringFromLiteral(kDesktopWindowXamlSourceClass, &className);
    if (FAILED(hr))
    {
        LogState(FN, "WindowsCreateString(DesktopWindowXamlSource) failed hr=0x%08X", (unsigned)hr);
        return hr;
    }

    hr = RoActivateInstance(className, &g_desktopWindowXamlSourceInspectable);
    LogState(FN, "RoActivateInstance(DesktopWindowXamlSource) hr=0x%08X", (unsigned)hr);
    WindowsDeleteString(className);
    if (FAILED(hr))
    {
        return hr;
    }

    hr = g_desktopWindowXamlSourceInspectable->lpVtbl->QueryInterface(
        g_desktopWindowXamlSourceInspectable,
        &IID_IDesktopWindowXamlSource,
        (void**)&g_desktopWindowXamlSource);
    LogState(FN, "QI(IDesktopWindowXamlSource) hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        return hr;
    }

    {
        Microsoft_UI_WindowId windowId;
        hr = GetWindowIdForHwnd(parentWindow, &windowId);
        if (FAILED(hr))
        {
            return hr;
        }
        hr = g_desktopWindowXamlSource->lpVtbl->Initialize(g_desktopWindowXamlSource, windowId);
        LogState(FN, "IDesktopWindowXamlSource::Initialize hr=0x%08X", (unsigned)hr);
        if (FAILED(hr))
        {
            return hr;
        }
    }

    hr = LoadTriangleXaml();
    return hr;
}

static void CleanupXamlIsland(void)
{
    LogState("CleanupXamlIsland", "begin");
    ReleaseIf((void**)&g_desktopWindowXamlSource);
    ReleaseIf((void**)&g_desktopWindowXamlSourceInspectable);
    ReleaseIf((void**)&g_windowsXamlManager);
    ReleaseIf((void**)&g_coreDispatcherQueueController);
    ReleaseIf((void**)&g_dispatcherQueueController);
    LogState("CleanupXamlIsland", "end");
}

static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
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

static HRESULT CreateMainWindow(HINSTANCE instance)
{
    const char* FN = "CreateMainWindow";
    const wchar_t* className = L"HelloWinUI3CWindow";
    WNDCLASSEXW wc;
    RECT rc;
    DWORD style = WS_OVERLAPPEDWINDOW;

    ZeroMemory(&wc, sizeof(wc));
    wc.cbSize = sizeof(wc);
    wc.hInstance = instance;
    wc.lpszClassName = className;
    wc.lpfnWndProc = WindowProc;
    wc.hCursor = LoadCursorW(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);

    if (!RegisterClassExW(&wc))
    {
        DWORD gle = GetLastError();
        if (gle != ERROR_CLASS_ALREADY_EXISTS)
        {
            LogState(FN, "RegisterClassExW failed gle=%lu", gle);
            return HRESULT_FROM_WIN32(gle);
        }
    }

    rc.left = 0;
    rc.top = 0;
    rc.right = 960;
    rc.bottom = 540;
    AdjustWindowRect(&rc, style, FALSE);

    g_mainWindow = CreateWindowExW(
        0,
        className,
        L"Hello, World!",
        style,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        rc.right - rc.left,
        rc.bottom - rc.top,
        NULL,
        NULL,
        instance,
        NULL);

    if (!g_mainWindow)
    {
        DWORD gle = GetLastError();
        LogState(FN, "CreateWindowExW failed gle=%lu", gle);
        return HRESULT_FROM_WIN32(gle);
    }

    ShowWindow(g_mainWindow, SW_SHOW);
    UpdateWindow(g_mainWindow);
    LogState(FN, "window created hwnd=0x%p", g_mainWindow);
    return S_OK;
}

int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow)
{
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    const char* FN = "wWinMain";
    HRESULT hr;
    bool bootstrapInitialized = false;
    bool apartmentInitialized = false;
    bool roInitialized = false;
    int exitCode = 0;
    MSG msg;

    LogState(FN, "begin");

    {
        PACKAGE_VERSION minVersion;
        minVersion.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;
        hr = MddBootstrapInitialize2(
            WINDOWSAPPSDK_RELEASE_MAJORMINOR,
            WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
            minVersion,
            MddBootstrapInitializeOptions_None);
        LogState(FN, "MddBootstrapInitialize2 hr=0x%08X", (unsigned)hr);
        if (FAILED(hr))
        {
            exitCode = 1;
            goto cleanup;
        }
        bootstrapInitialized = true;
    }

    hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    LogState(FN, "CoInitializeEx hr=0x%08X", (unsigned)hr);
    if (SUCCEEDED(hr))
    {
        apartmentInitialized = true;
    }
    else if (hr != RPC_E_CHANGED_MODE)
    {
        exitCode = 1;
        goto cleanup;
    }

    hr = RoInitialize(RO_INIT_SINGLETHREADED);
    LogState(FN, "RoInitialize hr=0x%08X", (unsigned)hr);
    if (SUCCEEDED(hr) || hr == S_FALSE)
    {
        roInitialized = true;
    }
    else if (hr != RPC_E_CHANGED_MODE)
    {
        exitCode = 1;
        goto cleanup;
    }

    hr = EnsureDispatcherQueue();
    LogState(FN, "EnsureDispatcherQueue(from wWinMain) hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        exitCode = 1;
        goto cleanup;
    }

    hr = CreateMainWindow(hInstance);
    if (FAILED(hr))
    {
        exitCode = 1;
        goto cleanup;
    }

    hr = InitializeXamlIsland(g_mainWindow);
    LogState(FN, "InitializeXamlIsland hr=0x%08X", (unsigned)hr);
    if (FAILED(hr))
    {
        exitCode = 1;
        goto cleanup;
    }

    while (GetMessageW(&msg, NULL, 0, 0) > 0)
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
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
        MddBootstrapShutdown();
        LogState(FN, "MddBootstrapShutdown");
    }

    LogState(FN, "end exitCode=%d", exitCode);
    return exitCode;
}
