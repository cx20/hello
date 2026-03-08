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
#include <afxwin.h>

using namespace winrt::Microsoft::UI;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Hosting;
using namespace winrt::Microsoft::UI::Xaml::Media;
using namespace winrt::Microsoft::UI::Xaml::Shapes;

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

class CHelloApp;

class CMainFrame : public CFrameWnd
{
public:
    CMainFrame();
    BOOL PreCreateWindow(CREATESTRUCT& cs) override;

protected:
    afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
    afx_msg void OnSize(UINT nType, int cx, int cy);
    afx_msg void OnDestroy();
    DECLARE_MESSAGE_MAP()

private:
    bool InitializeXamlIsland();
    UIElement CreateTriangleContent();

    CWnd m_xamlHost;
    DesktopWindowXamlSource m_xamlSource{ nullptr };
};

class CHelloApp : public CWinApp
{
public:
    BOOL InitInstance() override;
    int ExitInstance() override;
    bool TryGetWindowId(HWND hwnd, winrt::Microsoft::UI::WindowId& outWindowId);

private:
    bool EnsureDispatcherQueue();
    bool InitializeBootstrap();
    void ShutdownBootstrap();

    bool m_bootstrapInitialized{ false };
    bool m_apartmentInitialized{ false };
    winrt::Microsoft::UI::Dispatching::DispatcherQueueController m_dispatcherQueueControllerWinRT{ nullptr };
    winrt::com_ptr<IUnknown> m_dispatcherQueueController;
    WindowsXamlManager m_windowsXamlManager{ nullptr };
    HMODULE m_frameworkUdk{ nullptr };
};

BEGIN_MESSAGE_MAP(CMainFrame, CFrameWnd)
    ON_WM_CREATE()
    ON_WM_SIZE()
    ON_WM_DESTROY()
END_MESSAGE_MAP()

CMainFrame::CMainFrame()
{
    Create(nullptr, _T("Hello, World!"));
}

BOOL CMainFrame::PreCreateWindow(CREATESTRUCT& cs)
{
    CFrameWnd::PreCreateWindow(cs);
    cs.cx = 960;
    cs.cy = 540;
    return TRUE;
}

int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
{
    if (CFrameWnd::OnCreate(lpCreateStruct) == -1)
    {
        return -1;
    }

    CRect rc;
    GetClientRect(&rc);
    if (!m_xamlHost.CreateEx(
            0,
            AfxRegisterWndClass(CS_HREDRAW | CS_VREDRAW),
            _T(""),
            WS_CHILD | WS_VISIBLE,
            rc,
            this,
            1001))
    {
        LogState("CMainFrame::OnCreate", "host window create failed");
        return -1;
    }

    if (!InitializeXamlIsland())
    {
        AfxMessageBox(_T("Failed to initialize WinUI3 XAML island."), MB_ICONERROR | MB_OK);
        return -1;
    }

    return 0;
}

void CMainFrame::OnSize(UINT nType, int cx, int cy)
{
    CFrameWnd::OnSize(nType, cx, cy);
    if (m_xamlHost.GetSafeHwnd() != nullptr)
    {
        m_xamlHost.MoveWindow(0, 0, cx, cy, TRUE);
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
    CFrameWnd::OnDestroy();
    LogState("CMainFrame::OnDestroy", "end");
}

UIElement CMainFrame::CreateTriangleContent()
{
    Canvas canvas;
    canvas.Background(SolidColorBrush(Colors::White()));

    winrt::Windows::Foundation::Point point1{ 300.0f, 100.0f };
    winrt::Windows::Foundation::Point point2{ 500.0f, 400.0f };
    winrt::Windows::Foundation::Point point3{ 100.0f, 400.0f };

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
    auto* app = static_cast<CHelloApp*>(AfxGetApp());
    if (app == nullptr)
    {
        return false;
    }

    m_xamlSource = DesktopWindowXamlSource();

    winrt::Microsoft::UI::WindowId windowId{};
    if (!app->TryGetWindowId(m_xamlHost.GetSafeHwnd(), windowId))
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

bool CHelloApp::InitializeBootstrap()
{
    PACKAGE_VERSION minVersion{};
    minVersion.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;

    const HRESULT hr = MddBootstrapInitialize2(
        WINDOWSAPPSDK_RELEASE_MAJORMINOR,
        WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
        minVersion,
        MddBootstrapInitializeOptions_None);

    LogState("CHelloApp::InitializeBootstrap", "hr=0x%08X", static_cast<unsigned>(hr));
    if (FAILED(hr))
    {
        return false;
    }

    m_bootstrapInitialized = true;
    return true;
}

void CHelloApp::ShutdownBootstrap()
{
    if (m_bootstrapInitialized)
    {
        MddBootstrapShutdown();
        m_bootstrapInitialized = false;
    }
}

bool CHelloApp::EnsureDispatcherQueue()
{
    auto currentQueue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
    if (currentQueue != nullptr)
    {
        return true;
    }

    try
    {
        m_dispatcherQueueControllerWinRT = winrt::Microsoft::UI::Dispatching::DispatcherQueueController::CreateOnCurrentThread();
        currentQueue = winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();
        LogState(
            "CHelloApp::EnsureDispatcherQueue",
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
            "CHelloApp::EnsureDispatcherQueue",
            "CreateOnCurrentThread failed hr=0x%08X; fallback to CoreMessaging",
            static_cast<unsigned>(e.code()));
    }

    if (m_dispatcherQueueController)
    {
        return true;
    }

    DispatcherQueueOptions options{};
    options.dwSize = sizeof(options);
    options.threadType = DQTYPE_THREAD_CURRENT;
    options.apartmentType = DQTAT_COM_STA;

    IUnknown* controller = nullptr;
    const HRESULT hr = CreateDispatcherQueueController(options, &controller);
    LogState("CHelloApp::EnsureDispatcherQueue", "CreateDispatcherQueueController hr=0x%08X", static_cast<unsigned>(hr));
    if (FAILED(hr))
    {
        return false;
    }

    m_dispatcherQueueController.attach(controller);
    return true;
}

bool CHelloApp::TryGetWindowId(HWND hwnd, winrt::Microsoft::UI::WindowId& outWindowId)
{
    outWindowId = {};

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
        LogState("CHelloApp::TryGetWindowId", "LoadLibrary failed");
        return false;
    }

    const auto proc = reinterpret_cast<PfnWindowing_GetWindowIdFromWindow>(
        GetProcAddress(m_frameworkUdk, "Windowing_GetWindowIdFromWindow"));
    if (proc == nullptr)
    {
        LogState("CHelloApp::TryGetWindowId", "GetProcAddress failed");
        return false;
    }

    const HRESULT hr = proc(hwnd, &outWindowId);
    LogState("CHelloApp::TryGetWindowId", "Windowing_GetWindowIdFromWindow hr=0x%08X value=%llu", static_cast<unsigned>(hr), outWindowId.Value);
    return SUCCEEDED(hr);
}

BOOL CHelloApp::InitInstance()
{
    CWinApp::InitInstance();

    if (!InitializeBootstrap())
    {
        AfxMessageBox(_T("MddBootstrapInitialize2 failed."), MB_ICONERROR | MB_OK);
        return FALSE;
    }

    try
    {
        winrt::init_apartment(winrt::apartment_type::single_threaded);
        m_apartmentInitialized = true;
    }
    catch (...)
    {
        AfxMessageBox(_T("winrt::init_apartment failed."), MB_ICONERROR | MB_OK);
        ShutdownBootstrap();
        return FALSE;
    }

    if (!EnsureDispatcherQueue())
    {
        AfxMessageBox(_T("CreateDispatcherQueueController failed."), MB_ICONERROR | MB_OK);
        if (m_apartmentInitialized)
        {
            winrt::uninit_apartment();
            m_apartmentInitialized = false;
        }
        ShutdownBootstrap();
        return FALSE;
    }

    try
    {
        m_windowsXamlManager = WindowsXamlManager::InitializeForCurrentThread();
    }
    catch (winrt::hresult_error const& e)
    {
        LogState(
            "CHelloApp::InitInstance",
            "WindowsXamlManager::InitializeForCurrentThread failed hr=0x%08X; continue with DesktopWindowXamlSource path",
            static_cast<unsigned>(e.code()));
    }

    m_pMainWnd = new CMainFrame();
    m_pMainWnd->ShowWindow(m_nCmdShow);
    m_pMainWnd->UpdateWindow();
    return TRUE;
}

int CHelloApp::ExitInstance()
{
    LogState("CHelloApp::ExitInstance", "begin");

    m_windowsXamlManager = nullptr;
    m_dispatcherQueueControllerWinRT = nullptr;
    m_dispatcherQueueController = nullptr;

    if (m_apartmentInitialized)
    {
        winrt::uninit_apartment();
        m_apartmentInitialized = false;
    }

    ShutdownBootstrap();

    LogState("CHelloApp::ExitInstance", "end");
    return CWinApp::ExitInstance();
}

CHelloApp theApp;
