Option Strict On
Option Explicit On

Imports System
Imports System.Runtime.InteropServices
Imports Shell32

Module Hello
    Sub Main()
        ' NOTE: Avoid `New Shell()` if your environment breaks on IShellDispatch6.
        ' Use ProgID + IShellDispatch for compatibility.
        Dim shellType As Type = Type.GetTypeFromProgID("Shell.Application")
        Dim shell As IShellDispatch = CType(Activator.CreateInstance(shellType), IShellDispatch)

        Dim vRootFolder As Object = CInt(ShellSpecialFolderConstants.ssfWINDOWS)

        Dim folder As Folder = shell.BrowseForFolder(0, "Hello, COM(VB.NET) World!", 0, vRootFolder)

        If folder IsNot Nothing Then
            Console.WriteLine("Selected: " & folder.Title)
            Marshal.FinalReleaseComObject(folder)
        End If

        Marshal.FinalReleaseComObject(shell)
    End Sub
End Module
