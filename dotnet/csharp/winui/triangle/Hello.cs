using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using System.Diagnostics;
using Windows.Foundation;

namespace WinUI3LooseLike;

public sealed partial class Hello : Window
{
    private bool _triangleDrawn;

    public Hello()
    {
        Trace.WriteLine("[Hello] ctor: InitializeComponent skipped (code-only UI)");

        canvas = new Microsoft.UI.Xaml.Controls.Canvas
        {
            Background = new SolidColorBrush(Colors.White),
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };

        Content = canvas;

        this.Activated += Hello_Activated;
        canvas.Loaded += Canvas_Loaded;
        canvas.SizeChanged += Canvas_SizeChanged;
    }

    private void Hello_Activated(object sender, WindowActivatedEventArgs args)
    {
        Trace.WriteLine($"[Hello] Activated: State={args.WindowActivationState}");
    }

    private void Canvas_Loaded(object sender, RoutedEventArgs e)
    {
        Trace.WriteLine($"[Hello] Canvas.Loaded: ActualSize=({canvas.ActualWidth},{canvas.ActualHeight})");
        DrawTriangleOnce();
    }

    private void Canvas_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        Trace.WriteLine($"[Hello] Canvas.SizeChanged: NewSize=({e.NewSize.Width},{e.NewSize.Height})");
    }

    private void DrawTriangleOnce()
    {
        if (_triangleDrawn)
        {
            Trace.WriteLine("[Hello] DrawTriangleOnce: already drawn, skip");
            return;
        }

        _triangleDrawn = true;
        DrawTriangle();
    }

    private void DrawTriangle()
    {
        Trace.WriteLine("[Hello] DrawTriangle: begin");
        Point point1 = new Point(300, 100);
        Point point2 = new Point(500, 400);
        Point point3 = new Point(100, 400);

        var figure = new PathFigure { StartPoint = point1, IsClosed = true, IsFilled = true };
        figure.Segments.Add(new LineSegment { Point = point2 });
        figure.Segments.Add(new LineSegment { Point = point3 });

        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);

        var brush = new LinearGradientBrush();
        brush.GradientStops.Add(new GradientStop { Color = Colors.Red, Offset = 0.0 });
        brush.GradientStops.Add(new GradientStop { Color = Colors.Green, Offset = 0.5 });
        brush.GradientStops.Add(new GradientStop { Color = Colors.Blue, Offset = 1.0 });

        var path = new Microsoft.UI.Xaml.Shapes.Path
        {
            Data = geometry,
            Fill = brush,
            Stroke = new SolidColorBrush(Colors.Black),
            StrokeThickness = 1
        };

        canvas.Children.Add(path);
        Trace.WriteLine($"[Hello] DrawTriangle: end, canvas.Children.Count={canvas.Children.Count}");
    }
}
