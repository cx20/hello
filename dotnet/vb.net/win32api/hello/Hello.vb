Imports System
Imports System.Runtime.InteropServices

Module Hello
    Declare Auto Function MessageBox Lib "user32.dll" Alias "MessageBox" ( _
        ByVal hWnd As IntPtr, _
        ByVal lpText As String, _
        ByVal lpCaption As String, _
        ByVal nType As UInteger _
    ) As Integer
 
    Sub Main()
        MessageBox( New IntPtr(0), "Hello, Win32 API(VB.NET) World!", "Hello, World!", 0 )
    End Sub
End Module
