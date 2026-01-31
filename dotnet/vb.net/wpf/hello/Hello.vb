Imports System
Imports System.IO
Imports System.Windows
Imports System.Windows.Markup

Public Class Hello
	<STAThread()>
	Public Shared Sub Main()
		Dim window As Window = Nothing
		Using fileStream As FileStream = New FileStream("Hello.xaml", FileMode.Open)
			window = CType(XamlReader.Load(fileStream), Window)
		End Using
		window.Show()
		Dim application As Application = New Application()
		application.Run(window)
	End Sub
End Class
