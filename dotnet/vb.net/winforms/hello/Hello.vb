Imports System
Imports System.Drawing
Imports System.Windows.Forms
 
Class HelloForm
    Inherits Form
 
    Public Sub New()
        Me.Size = New Size( 640, 480 )
        Me.Text = "Hello, World!"
 
        Dim label1 As New Label
        label1.Size = New Size( 320, 20 )
        label1.Text = "Hello, Windows Forms(VB.NET) World!"
 
        Me.Controls.Add( label1 )
    End Sub
 
    <STAThread> _
    Shared Sub Main()
        Dim form As New HelloForm()
        Application.Run(form)
    End Sub
End Class
