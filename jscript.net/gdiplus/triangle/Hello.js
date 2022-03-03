import System;
import System.Drawing;
import System.Drawing.Drawing2D
import System.Windows.Forms;
import Accessibility;
 
main();
 
class HelloForm extends Form
{
    function HelloForm()
    {
        this.Size = new System.Drawing.Size( 640, 480 );
        this.Text = "Hello, World!";
    }
    protected override function OnPaint(e:PaintEventArgs) {
        var g = e.Graphics;
        var WIDTH  = 640; // this.Size.Width;
        var HEIGHT = 480; // this.Size.Height;
        
        var path = new GraphicsPath();
        var points:Point[] = [
            new Point(WIDTH * 1 / 2, HEIGHT * 1 / 4),
            new Point(WIDTH * 3 / 4, HEIGHT * 3 / 4),
            new Point(WIDTH * 1 / 4, HEIGHT * 3 / 4)
        ];
        path.AddLines(points);
        
        var pthGrBrush = new PathGradientBrush(path);
        pthGrBrush.CenterColor = Color.FromArgb(255, 255/3, 255/3, 255/3);
        pthGrBrush.SurroundColors = [
            Color.FromArgb(255, 255,   0,   0),
            Color.FromArgb(255,   0, 255,   0),
            Color.FromArgb(255,   0,   0, 255)
        ];
        g.FillPath(pthGrBrush, path);
    }
}

function main() {
    var form = new HelloForm;
    Application.Run(form);
}
