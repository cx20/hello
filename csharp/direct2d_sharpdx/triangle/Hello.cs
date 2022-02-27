using System;
using System.Windows.Forms;
using DX = SharpDX;
using D2D1 = SharpDX.Direct2D1;

static class Program
{
    private static void Main()
    {
        const int WIDTH = 640;
        const int HEIGHT = 480;

        Form form = new Form();
        form.ClientSize = new System.Drawing.Size(WIDTH, HEIGHT);
        form.Text = "Hello, World!";

        D2D1.HwndRenderTargetProperties hrtp = new D2D1.HwndRenderTargetProperties();
        hrtp.Hwnd = form.Handle;
        hrtp.PixelSize = new DX.Size2(WIDTH, HEIGHT);

        D2D1.Factory dx2dFactory = new D2D1.Factory();
        D2D1.WindowRenderTarget rt = new D2D1.WindowRenderTarget(dx2dFactory, new D2D1.RenderTargetProperties(), hrtp);

        form.Shown += (sender, e) =>
        {
            DX.Vector2 p1 = new DX.Vector2(WIDTH * 1 / 2, HEIGHT * 1 / 4);
            DX.Vector2 p2 = new DX.Vector2(WIDTH * 3 / 4, HEIGHT * 3 / 4);
            DX.Vector2 p3 = new DX.Vector2(WIDTH * 1 / 4, HEIGHT * 3 / 4);

            rt.BeginDraw();

            rt.Clear(DX.Color.White);

            D2D1.SolidColorBrush brush = new D2D1.SolidColorBrush(rt, DX.Color.Blue);

            rt.DrawLine(p1, p2, brush);
            rt.DrawLine(p2, p3, brush);
            rt.DrawLine(p3, p1, brush);

            rt.EndDraw();
        };

        form.ShowDialog();
    }
}

