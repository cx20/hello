using Microsoft.UI.Xaml;
using System;
using System.Diagnostics;
using System.IO;

namespace Hello;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
        UnhandledException += App_UnhandledException;

        // Write a simple log next to the executable for troubleshooting.
        var logPath = Path.Combine(AppContext.BaseDirectory, "triangle.log");
        Trace.Listeners.Add(new TextWriterTraceListener(logPath));
        Trace.AutoFlush = true;

        Trace.WriteLine($"[App] ctor: InitializeComponent done, log={logPath}");
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        Trace.WriteLine("[App] OnLaunched: begin");
        _window = new Hello();
        _window.Activate();
        Trace.WriteLine("[App] OnLaunched: window activated");
    }

    // IMPORTANT:
    // Use the WinUI event args type explicitly to avoid ambiguity with System.UnhandledExceptionEventArgs.
    private void App_UnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        Trace.WriteLine($"[App] UnhandledException: {e.Exception}");
    }
}
