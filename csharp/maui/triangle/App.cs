using Microsoft.Maui.Controls;

namespace MauiTriangleWin;

public class App : Application
{
    protected override Window CreateWindow(IActivationState? activationState)
    {
        var window = new Window(new MainPage())
        {
            Title = "Hello, World!"
        };

        return window;
    }
}
