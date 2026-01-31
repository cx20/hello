Imports System
Imports System.Runtime.InteropServices

Module Hello
    Sub Main()
        Dim shell As Object
        Dim folder As Object
        shell = CreateObject("Shell.Application")
        folder = shell.BrowseForFolder(0, "Hello, COM(VB.NET) World!", 0, 36)
        If Not folder Is Nothing Then
            Marshal.ReleaseComObject(folder)
        End If
        Marshal.ReleaseComObject(shell)
    End Sub
End Module
