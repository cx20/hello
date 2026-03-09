// hello.cpp - WinUI3 XAML Island Triangle Sample using WTL
//
// Draws a gradient-filled triangle via WinUI3 XAML DesktopWindowXamlSource
// hosted inside a WTL frame window.

#include <winsock2.h>
#include <windows.h>
#ifdef GetCurrentTime
#undef GetCurrentTime
#endif
#ifdef ALL
#undef ALL
#endif
#include <cstdarg>
#include <cstdio>
#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Microsoft.UI.h>
#include <winrt/Microsoft.UI.Dispatching.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Hosting.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>
#include <atlbase.h>
#include <atlapp.h>
#include <atlwin.h>
#include <atlframe.h>
#include <atlcrack.h>
#include <atlmisc.h>

using namespace winrt::Microsoft::UI;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Hosting;
using namespace winrt::Microsoft::UI::Xaml::Media;
using namespace winrt::Microsoft::UI::Xaml::Shapes;

// DispatcherQueue interop types
typedef enum DISPATCHERQUEUE_THREAD_TYPE
{
    DQTYPE_THREAD_DEDICATED = 1,
    DQTYPE_THREAD_CURRENT = 2
} DISPATCHERQUEUE_THREAD_TYPE;

typedef enum DISPATCHERQUEUE_THREAD_APARTMENTTYPE
{
    DQTAT_COM_NONE = 0,
    DQTAT_COM_ASTA = 1,
    DQTAT_COM_STA = 2
} DISPATCHERQUEUE_THREAD_APARTMENTTYPE;

typedef struct DispatcherQueueOptions
{
    DWORD dwSize;
    DISPATCHERQUEUE_THREAD_TYPE threadType;
    DISPATCHERQUEUE_THREAD_APARTMENTTYPE apartmentType;
} DispatcherQueueOptions;

STDAPI CreateDispatcherQueueController(
    DispatcherQueueOptions options,
    IUnknown** dispatcherQueueController);

typedef HRESULT(STDAPICALLTYPE* PfnWindowing_GetWindowIdFromWindow)(
    HWND hwnd,
    winrt::Microsoft::UI::WindowId* windowId);

// Debug logging helper
static void LogState(const char* functionName, const char* fmt, ...)
{
    char body[768] = {};
    va_list args;
    va_start(args, fmt);
    vsnprintf(body, sizeof(body), fmt, args);
    va_end(args);

    char line[1024] = {};
    snprintf(line, sizeof(line), "[%s] %s\n", functionName, body);
    OutputDebugStringA(line);
}

// WTL module instance
CAppModule _Module;

// Forward declaration
class CMainFrame;

//---------------------------------------------------------------------
// Application helper: bootstrap, dispatcher queue, WindowId resolution
//---------------------------------------------------------------------
class CApplication
{
public:
    bool InitializeBootstrap();
    void ShutdownBootstrap();
    bool EnsureDispatcherQueue();
    bool TryGetWindowId(HWND hwnd, winrt::Microsoft::UI::WindowId& outWindowId);

    void Shutdown();

    bool m_bootstrapInitialized{ false };
    bool m_apartmentInitialized{ false };
    winrt::Microsoft::UI::Dispatching::DispatcherQueueController m_dispatcherQueueControllerWinRT{ nullptr };
    winrt::com_ptr<IUnknown> m_dispatcherQueueController;
    WindowsXamlManager m_windowsXamlManager{ nullptr };
    HMODULE m_frameworkUdk{ nullptr };
};

// Global application object
static CApplication g_app;

//---------------------------------------------------------------------
// CMainFrame - WTL frame window hosting the XAML island
//---------------------------------------------------------------------
class CMainFrame : public CFrameWindowImpl<CMainFrame>
{
public:
    DECLARE_FRAME_WND_CLASS(nullptr, 0)

    BEGIN_MSG_MAP(CMainFrame)
        MSG_WM_CREATE(OnCreate)
        MSG_WM_SIZE(OnSize)
        MSG_WM_DESTROY(OnDestroy)
        CHAIN_MSG_MAP(CFrameWindowImpl<CMainFrame>)
    END_MSG_MAP()

private:
    int OnCreate(LPCREATESTRUCT lpCreateStruct);
    void OnSize(UINT nType, CSize size);
    void OnDestroy();

    bool InitializeXamlIsland();
    UIElement CreateTriangleContent();

    CWindow m_xamlHost;
    DesktopWindowXamlSource m_xamlSource{ nullptr };
};

//---------------------------------------------------------------------
// CMainFrame implementation
//---------------------------------------------------------------------
int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    RECT rc;
    GetClientRect(&rc);

    // Register a simple window class for the XAML host child window
    WNDCLASSEX wcex = { sizeof(WNDCLASSEX) };
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = ::DefWindowProc;
    wcex.hInstance = _Module.GetModuleInstance();
    wcex.lpszClassName = _T("XamlHostClass");
    ::RegisterClassEx(&wcex);

    // Create child window that will host the XAML island
    HWND hHost = ::CreateWindowEx(
        0,
        _T("XamlHostClass"),
        _T(""),
        WS_CHILD | WS_VISIBLE,
        0, 0,
        rc.right - rc.left,
        rc.bottom - rc.top,
        m_hWnd,
        reinterpret_cast<HMENU>(static_cast<INT_PTR>(1001)),
        _Module.GetModuleInstance(),
        nullptr);

    if (hHost == nullptr)
    {
        LogState("CMainFrame::OnCreate", "host window create failed");
        return -1;
    }

    m_xamlHost = hHost;

    if (!InitializeXamlIsland())
    {
        ::MessageBox(m_hWnd, _T("Failed to initialize WinUI3 XAML island."), _T("Error"), MB_ICONERROR | MB_OK);
        return -1;
    }

    return 0;
}

void CMainFrame::OnSize(UINT nType, CSize size)
{
    SetMsgHandled(FALSE);
    if (m_xamlHost.IsWindow())
    {
        m_xamlHost.MoveWindow(0, 0, size.cx, size.cy, TRUE);
    }
}

void CMainFrame::OnDestroy()
{
    LogState("CMainFrame::OnDestroy", "begin");
    if (m_xamlSource)
    {
        m_xamlSource.Content(nullptr);
        m_xamlSource.Close();
        m_xamlSource = nullptr;
    }
    ::PostQuitMessage(0);
    LogState("CMainFrame::OnDestroy", "end");
}

UIElement CMainFrame::CreateTriangleContent()
{
    Canvas canvas;
    canvas.Background(SolidColorBrush(Colors::White()));

    // Triangle vertices
    winrt::Windows::Foundation::Point point1{ 300.0f, 100.0f };
    winrt::Windows::Foundation::Point point2{ 500.0f, 400.0f };
    winrt::Windows::Foundation::Point point3{ 100.0f, 400.0f };

    // Build path geometry
    PathFigure figure;
    figure.StartPoint(point1);
    figure.IsClosed(true);
    figure.IsFilled(true);

    LineSegment line1;
    line1.Point(point2);
    figure.Segments().Append(line1);

    LineSegment line2;
    line2.Point(point3);
    figure.Segments().Append(line2);

    PathGeometry geometry;
    geometry.Figures().Append(figure);

    // Gradient fill: red -> green -> blue
    LinearGradientBrush brush;

    GradientStop stop1;
    stop1.Color(Colors::Red());
    stop1.Offset(0.0);
    brush.GradientStops().Append(stop1);

    GradientStop stop2;
    stop2.Color(Colors::Green());
    stop2.Offset(0.5);
    brush.GradientStops().Append(stop2);

    GradientStop stop3;
    stop3.Color(Colors::Blue());
    stop3.Offset(1.0);
    brush.GradientStops().Append(stop3);

    // Assemble the path shape
    Path path;
    path.Data(geometry);
    path.Fill(brush);
    path.Stroke(SolidColorBrush(Colors::Black()));
    path.StrokeThickness(1.0);

    canvas.Children().Append(path);
    return canvas;
}

bool CMainFrame::InitializeXamlIsland()
{
    m_xamlSource = DesktopWindowXamlSource();

    winrt::Microsoft::UI::WindowId windowId{};
    if (!g_app.TryGetWindowId(m_xamlHost.m_hWnd, windowId))
    {
        return false;
    }

    try
    {
        m_xamlSource.Initialize(windowId);
        m_xamlSource.Content(CreateTriangleContent());
    }
    catch (winrt::hresult_error const& e)
    {
        LogState("CMainFrame::InitializeXamlIsland", "hresult_error=0x%08X", static_cast<unsigned>(e.code()));
        return false;
    }
    catch (...)
    {
        LogState("CMainFrame::InitializeXamlIsland", "unknown exception");
        return false;
    }

    return true;
}

//---------------------------------------------------------------------
// CApplication implementation
//---------------------------------------------------------------------
bool CApplication::InitializeBootstrap()
{
    PACKAGE_VERSION minVersion{};
    minVersion.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;

    const HRESULT hr = MddBootstrapInitialize2(
        WINDOWSAPPSDK_RELEASE_MAJORMINOR,
        WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
        minVersion,
        MddBootstrapInitializeOptions_None);

    LogState("CApplication::InitializeBootstrap", "hr=0x%08X", static_cast<unsigned>(hr));
    if (FAILED(hr))
    {
        return false;
    }

    m_bootstrapInitialized = true;
    return true;
}

void CApplication::ShutdownBootstrap()
{
    if (m_bootstrapInitialized)
    {
        MddBootstrapShutdown();
        m_bootstrapInitialized = false;
    }
}

bool CApplication::EnsureDispatcherQueue()
{
    auto currentQueue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
    if (currentQueue != nullptr)
    {
        return true;
    }

    // Try WinUI3 DispatcherQueueController first
    try
    {
        m_dispatcherQueueControllerWinRT = winrt::Microsoft::UI::Dispatching::DispatcherQueueController::CreateOnCurrentThread();
        currentQueue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
        LogState(
            "CApplication::EnsureDispatcherQueue",
            "DispatcherQueueController::CreateOnCurrentThread queue=%p",
            currentQueue ? winrt::get_abi(currentQueue) : nullptr);
        if (currentQueue != nullptr)
        {
            return true;
        }
    }
    catch (winrt::hresult_error const& e)
    {
        LogState(
            "CApplication::EnsureDispatcherQueue",
            "CreateOnCurrentThread failed hr=0x%08X; fallback to CoreMessaging",
            static_cast<unsigned>(e.code()));
    }

    if (m_dispatcherQueueController)
    {
        return true;
    }

    // Fallback to CoreMessaging API
    DispatcherQueueOptions options{};
    options.dwSize = sizeof(options);
    options.threadType = DQTYPE_THREAD_CURRENT;
    options.apartmentType = DQTAT_COM_STA;

    IUnknown* controller = nullptr;
    const HRESULT hr = CreateDispatcherQueueController(options, &controller);
    LogState("CApplication::EnsureDispatcherQueue", "CreateDispatcherQueueController hr=0x%08X", static_cast<unsigned>(hr));
    if (FAILED(hr))
    {
        return false;
    }

    m_dispatcherQueueController.attach(controller);
    return true;
}

bool CApplication::TryGetWindowId(HWND hwnd, winrt::Microsoft::UI::WindowId& outWindowId)
{
    outWindowId = {};

    // Load FrameworkUdk to resolve HWND -> WindowId
    if (m_frameworkUdk == nullptr)
    {
        m_frameworkUdk = GetModuleHandleW(L"Microsoft.Internal.FrameworkUdk.dll");
        if (m_frameworkUdk == nullptr)
        {
            m_frameworkUdk = LoadLibraryW(L"Microsoft.Internal.FrameworkUdk.dll");
        }
    }

    if (m_frameworkUdk == nullptr)
    {
        LogState("CApplication::TryGetWindowId", "LoadLibrary failed");
        return false;
    }

    const auto proc = reinterpret_cast<PfnWindowing_GetWindowIdFromWindow>(
        GetProcAddress(m_frameworkUdk, "Windowing_GetWindowIdFromWindow"));
    if (proc == nullptr)
    {
        LogState("CApplication::TryGetWindowId", "GetProcAddress failed");
        return false;
    }

    const HRESULT hr = proc(hwnd, &outWindowId);
    LogState("CApplication::TryGetWindowId", "Windowing_GetWindowIdFromWindow hr=0x%08X value=%llu", static_cast<unsigned>(hr), outWindowId.Value);
    return SUCCEEDED(hr);
}

void CApplication::Shutdown()
{
    LogState("CApplication::Shutdown", "begin");

    m_windowsXamlManager = nullptr;
    m_dispatcherQueueControllerWinRT = nullptr;
    m_dispatcherQueueController = nullptr;

    if (m_apartmentInitialized)
    {
        winrt::uninit_apartment();
        m_apartmentInitialized = false;
    }

    ShutdownBootstrap();

    LogState("CApplication::Shutdown", "end");
}

//---------------------------------------------------------------------
// WinMain - entry point
//---------------------------------------------------------------------
int WINAPI _tWinMain(HINSTANCE hInstance, HINSTANCE /*hPrevInstance*/, LPTSTR lpCmdLine, int nCmdShow)
{
    // Initialize Windows App SDK bootstrap
    if (!g_app.InitializeBootstrap())
    {
        ::MessageBox(nullptr, _T("MddBootstrapInitialize2 failed."), _T("Error"), MB_ICONERROR | MB_OK);
        return 1;
    }

    // Initialize WinRT apartment
    try
    {
        winrt::init_apartment(winrt::apartment_type::single_threaded);
        g_app.m_apartmentInitialized = true;
    }
    catch (...)
    {
        ::MessageBox(nullptr, _T("winrt::init_apartment failed."), _T("Error"), MB_ICONERROR | MB_OK);
        g_app.ShutdownBootstrap();
        return 1;
    }

    // Create dispatcher queue for XAML
    if (!g_app.EnsureDispatcherQueue())
    {
        ::MessageBox(nullptr, _T("CreateDispatcherQueueController failed."), _T("Error"), MB_ICONERROR | MB_OK);
        if (g_app.m_apartmentInitialized)
        {
            winrt::uninit_apartment();
            g_app.m_apartmentInitialized = false;
        }
        g_app.ShutdownBootstrap();
        return 1;
    }

    // Initialize XAML manager
    try
    {
        g_app.m_windowsXamlManager = WindowsXamlManager::InitializeForCurrentThread();
    }
    catch (winrt::hresult_error const& e)
    {
        LogState(
            "WinMain",
            "WindowsXamlManager::InitializeForCurrentThread failed hr=0x%08X; continue with DesktopWindowXamlSource path",
            static_cast<unsigned>(e.code()));
    }

    // Initialize WTL module and message loop
    _Module.Init(nullptr, hInstance);
    CMessageLoop theLoop;
    _Module.AddMessageLoop(&theLoop);

    // Create and show the main frame window
    CMainFrame wndMain;
    if (wndMain.CreateEx(nullptr, nullptr, WS_OVERLAPPEDWINDOW) == nullptr)
    {
        ::MessageBox(nullptr, _T("Failed to create main window."), _T("Error"), MB_ICONERROR | MB_OK);
        _Module.RemoveMessageLoop();
        _Module.Term();
        g_app.Shutdown();
        return 1;
    }
    wndMain.SetWindowText(_T("Hello, World!"));
    wndMain.ResizeClient(960, 540);

    wndMain.ShowWindow(nCmdShow);
    wndMain.UpdateWindow();

    // Run the message loop
    int nRet = theLoop.Run();

    // Cleanup
    _Module.RemoveMessageLoop();
    _Module.Term();
    g_app.Shutdown();

    return nRet;
}