#include <windows.h>
#ifdef GetCurrentTime
#undef GetCurrentTime
#endif
#include <cstdarg>
#include <cstdio>
#include <exception>
#include <MddBootstrap.h>
#include <WindowsAppSDK-VersionInfo.h>
#include <winrt/base.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Shapes.h>

using namespace winrt;
using namespace winrt::Windows::Foundation;
using namespace winrt::Microsoft::UI;
using namespace winrt::Microsoft::UI::Xaml;
using namespace winrt::Microsoft::UI::Xaml::Controls;
using namespace winrt::Microsoft::UI::Xaml::Media;
using namespace winrt::Microsoft::UI::Xaml::Shapes;

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

struct HelloWindow : WindowT<HelloWindow>
{
    Canvas m_canvas{ nullptr };
    bool m_triangleDrawn{ false };

    HelloWindow()
    {
        LogState("HelloWindow::HelloWindow", "begin");
        Title(L"Hello, World!");

        m_canvas = Canvas();
        m_canvas.Background(SolidColorBrush(Colors::White()));
        m_canvas.HorizontalAlignment(HorizontalAlignment::Stretch);
        m_canvas.VerticalAlignment(VerticalAlignment::Stretch);
        Content(m_canvas);

        Activated({ this, &HelloWindow::OnActivated });
        m_canvas.Loaded({ this, &HelloWindow::OnCanvasLoaded });
        m_canvas.SizeChanged({ this, &HelloWindow::OnCanvasSizeChanged });
        LogState("HelloWindow::HelloWindow", "end");
    }

    void DrawTriangle()
    {
        LogState("HelloWindow::DrawTriangle", "begin");
        Point point1{ 300.0f, 100.0f };
        Point point2{ 500.0f, 400.0f };
        Point point3{ 100.0f, 400.0f };

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

        m_canvas.Children().Append(path);
        const auto childCount = m_canvas.Children().Size();
        LogState("HelloWindow::DrawTriangle", "triangle appended, children=%u", static_cast<unsigned>(childCount));
    }

    void DrawTriangleOnce()
    {
        LogState("HelloWindow::DrawTriangleOnce", "called, drawn=%d", m_triangleDrawn ? 1 : 0);
        if (m_triangleDrawn)
        {
            LogState("HelloWindow::DrawTriangleOnce", "skip");
            return;
        }
        m_triangleDrawn = true;
        DrawTriangle();
        LogState("HelloWindow::DrawTriangleOnce", "done");
    }

    void OnActivated(IInspectable const&, WindowActivatedEventArgs const&)
    {
        LogState("HelloWindow::OnActivated", "activated");
    }

    void OnCanvasLoaded(IInspectable const&, RoutedEventArgs const&)
    {
        LogState("HelloWindow::OnCanvasLoaded", "loaded");
        DrawTriangleOnce();
    }

    void OnCanvasSizeChanged(IInspectable const&, SizeChangedEventArgs const& e)
    {
        LogState(
            "HelloWindow::OnCanvasSizeChanged",
            "size changed: %.1f x %.1f",
            e.NewSize().Width,
            e.NewSize().Height);
    }
};

struct App : ApplicationT<App>
{
    Window m_window{ nullptr };

    void OnLaunched(LaunchActivatedEventArgs const&)
    {
        LogState("App::OnLaunched", "begin");
        m_window = make<HelloWindow>();
        m_window.Activate();
        LogState("App::OnLaunched", "window activated");
    }
};

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int)
{
    LogState("wWinMain", "begin");
    int exitCode = 0;
    bool bootstrapInitialized = false;

    try
    {
        PACKAGE_VERSION minVersion{};
        minVersion.Version = WINDOWSAPPSDK_RUNTIME_VERSION_UINT64;
        const HRESULT hrBootstrap = MddBootstrapInitialize2(
            WINDOWSAPPSDK_RELEASE_MAJORMINOR,
            WINDOWSAPPSDK_RELEASE_VERSION_TAG_W,
            minVersion,
            MddBootstrapInitializeOptions_None);
        LogState("wWinMain", "MddBootstrapInitialize2 hr=0x%08X", static_cast<unsigned>(hrBootstrap));
        if (FAILED(hrBootstrap))
        {
            throw winrt::hresult_error(hrBootstrap);
        }
        bootstrapInitialized = true;

        winrt::init_apartment(apartment_type::single_threaded);
        LogState("wWinMain", "apartment initialized");

        LogState("wWinMain", "before Application::Start");
        Application::Start([](auto&&) {
            LogState("Application::Start", "create App");
            make<App>();
            LogState("Application::Start", "App created");
        });
        LogState("wWinMain", "Application::Start returned");

        winrt::uninit_apartment();
        LogState("wWinMain", "apartment uninitialized");

        if (bootstrapInitialized)
        {
            MddBootstrapShutdown();
            bootstrapInitialized = false;
            LogState("wWinMain", "MddBootstrapShutdown done");
        }
    }
    catch (winrt::hresult_error const& e)
    {
        LogState("wWinMain", "hresult_error: 0x%08X", static_cast<unsigned>(e.code()));
        exitCode = 1;
    }
    catch (std::exception const& e)
    {
        LogState("wWinMain", "std::exception: %s", e.what());
        exitCode = 1;
    }
    catch (...)
    {
        LogState("wWinMain", "unknown exception");
        exitCode = 1;
    }

    if (bootstrapInitialized)
    {
        MddBootstrapShutdown();
        LogState("wWinMain", "MddBootstrapShutdown in exception path");
    }

    LogState("wWinMain", "end, exitCode=%d", exitCode);
    return exitCode;
}
