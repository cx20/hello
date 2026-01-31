Imports System
Imports System.Drawing
Imports System.Runtime.CompilerServices
Imports System.Windows.Forms
Imports SharpDX
Imports SharpDX.Direct2D1

Class Program
    Const WIDTH = 640
    Const HEIGHT = 480

    Public Shared Sub Main()
        Dim form As Form = New Form()
        form.ClientSize = New Size(WIDTH, HEIGHT)
        form.Text = "Hello, World!"

        Dim hwndProperties As HwndRenderTargetProperties = Nothing
        hwndProperties.Hwnd = form.Handle
        hwndProperties.PixelSize = New Size2(WIDTH, HEIGHT)

        Dim factory As Factory = New Factory()
        Dim rt As WindowRenderTarget = New WindowRenderTarget(factory, Nothing, hwndProperties)

        AddHandler form.Shown, _
            Sub(sender As Object, e As EventArgs)
                Dim value  As Vector2 = New Vector2(WIDTH * 1 / 2, HEIGHT * 1 / 4)
                Dim value2 As Vector2 = New Vector2(WIDTH * 3 / 4, HEIGHT * 3 / 4)
                Dim value3 As Vector2 = New Vector2(WIDTH * 1 / 4, HEIGHT * 3 / 4)

                rt.BeginDraw()
                rt.Clear(SharpDX.Color.White)
                Dim brush As SolidColorBrush = New SolidColorBrush(rt, SharpDX.Color.Blue)
                rt.DrawLine(value, value2, brush)
                rt.DrawLine(value2, value3, brush)
                rt.DrawLine(value3, value, brush)

                rt.EndDraw()
            End Sub

        form.ShowDialog()
    End Sub
End Class
