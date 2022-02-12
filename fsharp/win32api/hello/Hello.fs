open System
open System.Runtime.InteropServices

[<DllImport("user32.dll")>]
extern int MessageBox( UInt32 hWnd, String lpText, String lpCaption, UInt32 uType)
 
let x = MessageBox( 0u, "Hello, Win32 API(F#) World!", "Hello, World!", 0u )
