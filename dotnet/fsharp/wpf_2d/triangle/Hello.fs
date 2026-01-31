open System
open System.IO
open System.Windows
open System.Windows.Markup
open System.Windows.Media
open System.Windows.Shapes
open System.Windows.Controls

let drawTriangle (window: Window) =
    let canvas = window.Content :?> Canvas
    
    let point1 = Point(300.0, 100.0)
    let point2 = Point(500.0, 400.0)
    let point3 = Point(100.0, 400.0)
    
    let pathFigure = PathFigure()
    pathFigure.StartPoint <- point1
    pathFigure.Segments.Add(LineSegment(point2, true))
    pathFigure.Segments.Add(LineSegment(point3, true))
    pathFigure.Segments.Add(LineSegment(point1, true))
    
    let pathGeometry = PathGeometry()
    pathGeometry.Figures.Add(pathFigure)
    
    let path = Path()
    path.Data <- pathGeometry
    
    let brush = LinearGradientBrush()
    brush.GradientStops.Add(GradientStop(Colors.Red, 0.0))
    brush.GradientStops.Add(GradientStop(Colors.Green, 0.5))
    brush.GradientStops.Add(GradientStop(Colors.Blue, 1.0))
    
    path.Fill <- brush
    canvas.Children.Add(path)

[<STAThread>]
[<EntryPoint>]
let main argv = 
    let app = new Application()
    
    let window = 
        use fs = new FileStream("Hello.xaml", FileMode.Open)
        XamlReader.Load(fs) :?> Window
    
    drawTriangle window
    
    window.Show()
    
    app.Run(window)
