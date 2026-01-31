Imports Microsoft.DirectX
Imports Microsoft.DirectX.Direct3D
Imports System
Imports System.Drawing
Imports System.Windows.Forms

Friend Class Hello
    Inherits Form

    Private m_device As Device = Nothing

    Private Sub New()
        MyBase.ClientSize = New Size(640, 480)
        Me.Text = "Hello, World!"
    End Sub

    Private Sub InitGraphics()
        Me.m_device = New Device(0, DeviceType.Hardware, Me, CreateFlags.SoftwareVertexProcessing, New PresentParameters() { New PresentParameters() With { .Windowed = True, .SwapEffect = SwapEffect.Discard } })
    End Sub

    Protected Overrides Sub OnPaint(e As PaintEventArgs)
        Dim array As CustomVertex.TransformedColored() = New CustomVertex.TransformedColored(3 - 1) {}
        array(0).Position = New Vector4(300F, 100F, 0F, 1F)
        array(0).Color = Color.FromArgb(0, 255, 0).ToArgb()
        array(1).Position = New Vector4(500F, 400F, 0F, 1F)
        array(1).Color = Color.FromArgb(0, 0, 255).ToArgb()
        array(2).Position = New Vector4(100F, 400F, 0F, 1F)
        array(2).Color = Color.FromArgb(255, 0, 0).ToArgb()
        Me.m_device.Clear(ClearFlags.Target, Color.FromArgb(0, 0, 0).ToArgb(), 1F, 0)
        Me.m_device.BeginScene()
        Me.m_device.VertexFormat = (VertexFormats.Diffuse Or VertexFormats.Transformed)
        Me.m_device.DrawUserPrimitives(PrimitiveType.TriangleList, 1, array)
        Me.m_device.EndScene()
        Me.m_device.Present()
    End Sub

    <STAThread()> _
    Public Shared Sub Main()
        Dim hello As Hello = New Hello()
        hello.InitGraphics()
        Application.Run(hello)
    End Sub
End Class
