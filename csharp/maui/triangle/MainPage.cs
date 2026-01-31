using Microsoft.Maui.Graphics;

namespace MauiTriangleWin;

public class MainPage : ContentPage
{
    public MainPage()
    {
        Title = "MAUI Triangle (Windows)";

        var gv = new GraphicsView
        {
            Drawable = new TriangleDrawable(),
            HorizontalOptions = LayoutOptions.Fill,
            VerticalOptions = LayoutOptions.Fill
        };

        Content = gv;
    }

    private sealed class TriangleDrawable : IDrawable
    {
        public void Draw(ICanvas canvas, RectF dirtyRect)
        {
            canvas.FillColor = Colors.White;
            canvas.FillRectangle(dirtyRect);

            // 余白
            float m = 40f;

            // ウィンドウサイズに追従して三角形を作る
            var p1 = new PointF(dirtyRect.Center.X, m);
            var p2 = new PointF(dirtyRect.Right - m, dirtyRect.Bottom - m);
            var p3 = new PointF(dirtyRect.Left + m, dirtyRect.Bottom - m);

            var path = new PathF();
            path.MoveTo(p1);
            path.LineTo(p2);
            path.LineTo(p3);
            path.Close();

            canvas.FillColor = Colors.DeepSkyBlue;
            canvas.FillPath(path);

            canvas.StrokeColor = Colors.Black;
            canvas.StrokeSize = 2;
            canvas.DrawPath(path);
        }
    }
}
