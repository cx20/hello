using Microsoft.Maui.Controls;
using Microsoft.Maui.Hosting;
#if WINDOWS
using MauiTriangleWin.Platforms.Windows;
#endif

namespace MauiTriangleWin;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
            });

        builder.ConfigureMauiHandlers(handlers =>
        {
#if WINDOWS
            handlers.AddHandler<Win2DTriangleView, Win2DTriangleViewHandler>();
#endif
        });

        return builder.Build();
    }
}
