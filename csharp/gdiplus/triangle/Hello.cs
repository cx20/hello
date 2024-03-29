using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;
 
class HelloForm : Form
{
    public HelloForm()
    {
        this.Size = new Size(640, 480);
        this.Text = "Hello, World!";
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        int WIDTH  = this.Size.Width;
        int HEIGHT = this.Size.Height;
        
        GraphicsPath path = new GraphicsPath();
        Point[] points = new Point[] { 
            new Point(WIDTH * 1 / 2, HEIGHT * 1 / 4),
            new Point(WIDTH * 3 / 4, HEIGHT * 3 / 4),
            new Point(WIDTH * 1 / 4, HEIGHT * 3 / 4)
        };
        path.AddLines(points);
        
        PathGradientBrush pthGrBrush = new PathGradientBrush(path);
        pthGrBrush.CenterColor = Color.FromArgb(255, 255/3, 255/3, 255/3);
        pthGrBrush.SurroundColors = new Color[] {
            Color.FromArgb(255, 255,   0,   0),
            Color.FromArgb(255,   0, 255,   0),
            Color.FromArgb(255,   0,   0, 255)
        };
        e.Graphics.FillPath(pthGrBrush, path);
    }

    [STAThread]
    static void Main()
    {
        HelloForm form = new HelloForm();
        Application.Run(form);
    }
}
