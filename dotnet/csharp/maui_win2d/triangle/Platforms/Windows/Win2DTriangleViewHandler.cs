using Microsoft.Graphics.Canvas;
using Microsoft.Graphics.Canvas.Geometry;
using Microsoft.Graphics.Canvas.UI.Xaml;
using Microsoft.Maui.Handlers;
using Microsoft.UI.Xaml;
using System;
using System.Numerics;
using WinUIColor = Windows.UI.Color;

namespace MauiTriangleWin.Platforms.Windows;

public sealed class Win2DTriangleViewHandler : ViewHandler<Win2DTriangleView, CanvasControl>
{
    public static readonly IPropertyMapper<Win2DTriangleView, Win2DTriangleViewHandler> Mapper =
        new PropertyMapper<Win2DTriangleView, Win2DTriangleViewHandler>(ViewHandler.ViewMapper);

    public Win2DTriangleViewHandler() : base(Mapper)
    {
    }
    // Subdivision count:
    // Higher value => smoother gradient, but heavier CPU/GPU cost.
    // If it feels slow, try 60–100. If you want smoother, try 120–200.
    private const int N = 100;

    // Per-vertex colors (RGB triangle).
    // v0: top, v1: bottom-right, v2: bottom-left.
    private static readonly WinUIColor C0 = WinUIColor.FromArgb(255, 255, 0, 0);   // Red (top)
    private static readonly WinUIColor C1 = WinUIColor.FromArgb(255, 0, 255, 0);   // Green (right)
    private static readonly WinUIColor C2 = WinUIColor.FromArgb(255, 0, 0, 255);   // Blue (left)

    protected override CanvasControl CreatePlatformView()
    {
        var canvas = new CanvasControl();
        canvas.Draw += OnCanvasDraw;
        canvas.SizeChanged += OnCanvasSizeChanged;
        return canvas;
    }

    protected override void DisconnectHandler(CanvasControl platformView)
    {
        platformView.Draw -= OnCanvasDraw;
        platformView.SizeChanged -= OnCanvasSizeChanged;
        base.DisconnectHandler(platformView);
    }

    private void OnCanvasSizeChanged(object sender, SizeChangedEventArgs e)
    {
        if (sender is CanvasControl canvas)
        {
            canvas.Invalidate();
        }
    }

    private void OnCanvasDraw(CanvasControl sender, CanvasDrawEventArgs args)
    {
        DrawTriangle(args.DrawingSession, sender.Device, (float)sender.ActualWidth, (float)sender.ActualHeight);
    }

    private static void DrawTriangle(CanvasDrawingSession ds, CanvasDevice device, float width, float height)
    {
        // Clear background.
        ds.Clear(WinUIColor.FromArgb(255, 255, 255, 255));

        if (width <= 1 || height <= 1) return;

        // Margin around the triangle.
        float m = MathF.Min(width, height) * 0.06f + 20f;

        // Big triangle vertices:
        // v0 = top, v1 = bottom-right, v2 = bottom-left.
        Vector2 v0 = new(width * 0.5f, m);
        Vector2 v1 = new(width - m, height - m);
        Vector2 v2 = new(m, height - m);

        // To reduce seams between small triangles, Aliased often works better.
        // If you prefer smooth edges, switch to Antialiased (but seams may show up).
        ds.Antialiasing = CanvasAntialiasing.Aliased;

        // Triangle parameterization:
        // P(s, t) = v2 + s*(v1 - v2) + t*(v0 - v2),
        // with constraints s >= 0, t >= 0, s + t <= 1.
        //
        // We approximate vertex-color interpolation by subdividing the big triangle
        // into many small triangles and filling each one with an average color.
        for (int i = 0; i < N; i++)
        {
            float t0 = (float)i / N;
            float t1 = (float)(i + 1) / N;

            int cols = N - i;
            for (int j = 0; j < cols; j++)
            {
                float s0 = (float)j / N;
                float s1 = (float)(j + 1) / N;

                // Cell corners in (s, t) space:
                // A(s0, t0), B(s1, t0), C(s0, t1)
                Vector2 A = PointOnTriangle(v0, v1, v2, s0, t0);
                Vector2 B = PointOnTriangle(v0, v1, v2, s1, t0);
                Vector2 C = PointOnTriangle(v0, v1, v2, s0, t1);

                // The 4th corner D(s1, t1) exists only if s1 + t1 <= 1.
                // In this grid layout it is valid except for the last column.
                bool hasD = (j <= cols - 2);

                if (hasD)
                {
                    Vector2 D = PointOnTriangle(v0, v1, v2, s1, t1);

                    // Split the quad into two triangles:
                    //   △ A-B-D and △ A-D-C
                    FillSmallTriangle(ds, device, A, B, D, s0, t0, s1, t0, s1, t1);
                    FillSmallTriangle(ds, device, A, D, C, s0, t0, s1, t1, s0, t1);
                }
                else
                {
                    // Edge cell: only one triangle △ A-B-C.
                    FillSmallTriangle(ds, device, A, B, C, s0, t0, s1, t0, s0, t1);
                }
            }
        }

        // Optional outline.
        ds.Antialiasing = CanvasAntialiasing.Antialiased;
        var black = WinUIColor.FromArgb(255, 0, 0, 0);
        ds.DrawLine(v0, v1, black, 2f);
        ds.DrawLine(v1, v2, black, 2f);
        ds.DrawLine(v2, v0, black, 2f);
    }

    private static Vector2 PointOnTriangle(Vector2 v0, Vector2 v1, Vector2 v2, float s, float t)
    {
        // P(s, t) = v2 + s*(v1 - v2) + t*(v0 - v2)
        return v2 + s * (v1 - v2) + t * (v0 - v2);
    }

    private static void FillSmallTriangle(
        CanvasDrawingSession ds,
        CanvasDevice device,
        Vector2 p0, Vector2 p1, Vector2 p2,
        float s0, float t0,
        float s1, float t1,
        float s2, float t2)
    {
        // Compute colors at the three parametric vertices, then average them.
        // This reduces banding a bit compared to sampling only at the centroid.
        var c0 = ColorAt(s0, t0);
        var c1 = ColorAt(s1, t1);
        var c2 = ColorAt(s2, t2);

        float r = (c0.R + c1.R + c2.R) / (3f * 255f);
        float g = (c0.G + c1.G + c2.G) / (3f * 255f);
        float b = (c0.B + c1.B + c2.B) / (3f * 255f);

        WinUIColor fill = WinUIColor.FromArgb(
            255,
            (byte)(r * 255f),
            (byte)(g * 255f),
            (byte)(b * 255f));

        // Fill the small triangle.
        using var geo = CanvasGeometry.CreatePolygon(device, new[] { p0, p1, p2 });
        ds.FillGeometry(geo, fill);
    }

    private static WinUIColor ColorAt(float s, float t)
    {
        // Barycentric weights for the big triangle vertices:
        // w0 for v0 (top)    = t
        // w1 for v1 (right)  = s
        // w2 for v2 (left)   = 1 - s - t
        float w0 = t;
        float w1 = s;
        float w2 = 1f - s - t;

        // Clamp w2 to avoid negative values near the boundary due to float error.
        if (w2 < 0f) w2 = 0f;

        // Linearly blend vertex colors using barycentric weights.
        float r = w0 * C0.R + w1 * C1.R + w2 * C2.R;
        float g = w0 * C0.G + w1 * C1.G + w2 * C2.G;
        float b = w0 * C0.B + w1 * C1.B + w2 * C2.B;

        return WinUIColor.FromArgb(255, (byte)r, (byte)g, (byte)b);
    }
}
