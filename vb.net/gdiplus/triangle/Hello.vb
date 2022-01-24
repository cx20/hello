Imports System
Imports System.Drawing
Imports System.Drawing.Drawing2D
Imports System.Windows.Forms

Friend Class HelloForm
	Inherits Form

	Public Sub New()
		MyBase.Size = New Size(640, 480)
		Me.Text = "Hello, World!"
	End Sub

	Protected Overrides Sub OnPaint(e As PaintEventArgs)
		Dim width As Integer = MyBase.Size.Width
		Dim height As Integer = MyBase.Size.Height

		Dim graphicsPath As GraphicsPath = New GraphicsPath()
		Dim points As Point() = New Point() { 
			New Point(width * 1 / 2, height * 1 / 4), 
			New Point(width * 3 / 4, height * 3 / 4), 
			New Point(width * 1 / 4, height * 3 / 4) }
		graphicsPath.AddLines(points)

		Dim pathGradientBrush As PathGradientBrush = New PathGradientBrush(graphicsPath)
		pathGradientBrush.CenterColor = Color.FromArgb(255, 85, 85, 85)
		pathGradientBrush.SurroundColors = New Color() { 
			Color.FromArgb(255, 255, 0, 0), 
			Color.FromArgb(255, 0, 255, 0), 
			Color.FromArgb(255, 0, 0, 255) }
		e.Graphics.FillPath(pathGradientBrush, graphicsPath)
	End Sub

	<STAThread()> _
	Shared Sub Main()
		Dim mainForm As HelloForm = New HelloForm()
		Application.Run(mainForm)
	End Sub
End Class
