using System;
using System.IO;
using System.Windows;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Shapes;
using Canvas = System.Windows.Controls.Canvas;


public class Hello
{
    [STAThread]
    public static void Main()
    {
        Window window = null;
        using (FileStream fs = new FileStream("Hello.xaml", FileMode.Open))
        {
            window = (Window)XamlReader.Load(fs);
        }

        DrawTriangle(window);

        window.Show();

        Application app = new Application();
        app.Run(window);
    }

    private static void DrawTriangle(Window window)
    {
        Canvas canvas = (Canvas)window.Content;

        Point point1 = new Point(300, 100);
        Point point2 = new Point(500, 400);
        Point point3 = new Point(100, 400);

        PathFigure pathFigure = new PathFigure();
        pathFigure.StartPoint = point1;
        pathFigure.Segments.Add(new LineSegment(point2, true));
        pathFigure.Segments.Add(new LineSegment(point3, true));
        pathFigure.Segments.Add(new LineSegment(point1, true));

        PathGeometry pathGeometry = new PathGeometry();
        pathGeometry.Figures.Add(pathFigure);

        System.Windows.Shapes.Path path = new System.Windows.Shapes.Path();
        path.Data = pathGeometry;

        LinearGradientBrush brush = new LinearGradientBrush();
        brush.GradientStops.Add(new GradientStop(Colors.Red, 0.0));
        brush.GradientStops.Add(new GradientStop(Colors.Green, 0.5));
        brush.GradientStops.Add(new GradientStop(Colors.Blue, 1.0));

        path.Fill = brush;

        canvas.Children.Add(path);
    }
}
