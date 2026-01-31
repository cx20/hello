using Microsoft.Maui.Controls;
using Microsoft.Maui.Graphics;

namespace MauiTriangleWin;

public class MainPage : ContentPage
{
    public MainPage()
    {
        Title = "Vertex Color Triangle (Approx)";

        Content = new GraphicsView
        {
            Drawable = new VertexColorTriangleDrawable(),
            HorizontalOptions = LayoutOptions.Fill,
            VerticalOptions = LayoutOptions.Fill
        };
    }

    private sealed class VertexColorTriangleDrawable : IDrawable
    {
        // Subdivision count: higher = smoother but heavier.
        // Start with 120. If it's slow, try 80. If you want smoother, try 160-220.
        private const int N = 80;

        // Vertex colors (RGB triangle)
        private static readonly Color C0 = Colors.Red;   // Vertex 0 (top)
        private static readonly Color C1 = Colors.Lime;  // Vertex 1 (bottom-right)
        private static readonly Color C2 = Colors.Blue;  // Vertex 2 (bottom-left)

        public void Draw(ICanvas canvas, RectF dirtyRect)
        {
            // Clear background.
            canvas.FillColor = Colors.White;
            canvas.FillRectangle(dirtyRect);

            // Margin around the triangle.
            float m = MathF.Min(dirtyRect.Width, dirtyRect.Height) * 0.06f + 20f;

            // Define the big triangle vertices (responsive to window size).
            PointF v0 = new(dirtyRect.Center.X, dirtyRect.Top + m);     // Top
            PointF v1 = new(dirtyRect.Right - m, dirtyRect.Bottom - m); // Bottom-right
            PointF v2 = new(dirtyRect.Left + m, dirtyRect.Bottom - m);  // Bottom-left

            // If you see thin seams between small triangles, try:
            //   canvas.Antialias = false;
            // or increase N a bit.
            canvas.Antialias = false;

            // Parameterization:
            // P(s,t) = v2 + s*(v1-v2) + t*(v0-v2), with s>=0, t>=0, s+t<=1
            for (int i = 0; i < N; i++)
            {
                float t0 = (float)i / N;
                float t1 = (float)(i + 1) / N;

                int cols = N - i;
                for (int j = 0; j < cols; j++)
                {
                    float s0 = (float)j / N;
                    float s1 = (float)(j + 1) / N;

                    // Cell corners in (s,t) space:
                    // A(s0,t0), B(s1,t0), C(s0,t1)
                    var A = PointOnTriangle(v0, v1, v2, s0, t0);
                    var B = PointOnTriangle(v0, v1, v2, s1, t0);
                    var C = PointOnTriangle(v0, v1, v2, s0, t1);

                    // The 4th corner D(s1,t1) is valid only if s1 + t1 <= 1.
                    // In this grid layout, it's valid when we're not on the last column.
                    bool hasD = (j <= cols - 2);

                    if (hasD)
                    {
                        var D = PointOnTriangle(v0, v1, v2, s1, t1);

                        // Split the quad into two triangles:
                        // △ A-B-D and △ A-D-C
                        FillSmallTriangle(canvas, A, B, D, s0, t0, s1, t0, s1, t1);
                        FillSmallTriangle(canvas, A, D, C, s0, t0, s1, t1, s0, t1);
                    }
                    else
                    {
                        // Edge cell: only one triangle △ A-B-C.
                        FillSmallTriangle(canvas, A, B, C, s0, t0, s1, t0, s0, t1);
                    }
                }
            }

            // Optional outline.
            canvas.StrokeColor = Colors.Black;
            canvas.StrokeSize = 2;
            canvas.DrawLine(v0, v1);
            canvas.DrawLine(v1, v2);
            canvas.DrawLine(v2, v0);
        }

        private static PointF PointOnTriangle(PointF v0, PointF v1, PointF v2, float s, float t)
        {
            // P(s,t) = v2 + s*(v1-v2) + t*(v0-v2)
            float x = v2.X + s * (v1.X - v2.X) + t * (v0.X - v2.X);
            float y = v2.Y + s * (v1.Y - v2.Y) + t * (v0.Y - v2.Y);
            return new PointF(x, y);
        }

        private static void FillSmallTriangle(
            ICanvas canvas,
            PointF p0, PointF p1, PointF p2,
            float s0, float t0,
            float s1, float t1,
            float s2, float t2)
        {
            // Use the average of the three vertex colors (less banding than centroid sampling).
            var c0 = ColorAt(s0, t0);
            var c1 = ColorAt(s1, t1);
            var c2 = ColorAt(s2, t2);

            float r = (c0.Red + c1.Red + c2.Red) / 3f;
            float g = (c0.Green + c1.Green + c2.Green) / 3f;
            float b = (c0.Blue + c1.Blue + c2.Blue) / 3f;

            canvas.FillColor = new Color(r, g, b);

            var path = new PathF();
            path.MoveTo(p0);
            path.LineTo(p1);
            path.LineTo(p2);
            path.Close();

            canvas.FillPath(path);
        }

        private static Color ColorAt(float s, float t)
        {
            // Barycentric weights for vertices:
            // w0 for v0 (top)    = t
            // w1 for v1 (right)  = s
            // w2 for v2 (left)   = 1 - s - t
            float w0 = t;
            float w1 = s;
            float w2 = 1f - s - t;
            if (w2 < 0f) w2 = 0f;

            // IMPORTANT:
            // Microsoft.Maui.Graphics.Color constructor expects float components.
            // So keep everything as float (or cast).
            float r = w0 * C0.Red   + w1 * C1.Red   + w2 * C2.Red;
            float g = w0 * C0.Green + w1 * C1.Green + w2 * C2.Green;
            float b = w0 * C0.Blue  + w1 * C1.Blue  + w2 * C2.Blue;

            return new Color(r, g, b);
        }
    }
}
