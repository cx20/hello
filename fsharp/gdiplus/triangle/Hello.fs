open System;
open System.Drawing;
open System.Drawing.Drawing2D
open System.Windows.Forms;

type HelloForm = class
    inherit Form
 
    val mutable g : Graphics
    val mutable position : Point

    new () as form = {g=null;position = new Point(0,0)} then
         form.Size <- Size(640, 480);
         form.Text <- "Hello, World!";
         form.Show()

    override form.OnPaint e =
        let g = e.Graphics in
            let WIDTH  = form.Width;
            let HEIGHT = form.Height;
            
            let points: Point[] = [|
                new Point(WIDTH * 1 / 2, HEIGHT * 1 / 4);
                new Point(WIDTH * 3 / 4, HEIGHT * 3 / 4);
                new Point(WIDTH * 1 / 4, HEIGHT * 3 / 4)|];

            let path = new GraphicsPath()
            path.AddLines(points);

            let pthGrBrush = new PathGradientBrush(path);
            pthGrBrush.CenterColor <- Color.FromArgb(255, 255/3, 255/3, 255/3);

            let colors: Color[] = [|
                Color.FromArgb(255, 255,   0,   0);
                Color.FromArgb(255,   0, 255,   0);
                Color.FromArgb(255,   0,   0, 255)|];

            pthGrBrush.SurroundColors <- colors;
            e.Graphics.FillPath(pthGrBrush, path);
end

let form = new HelloForm()
do Application.Run(form)
