using Microsoft.Maui;
using Microsoft.Maui.Hosting;

namespace MauiTriangleWin.WinUI;

public partial class App : MauiWinUIApplication
{
    public App()
    {
        InitializeComponent();
    }

    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
}
