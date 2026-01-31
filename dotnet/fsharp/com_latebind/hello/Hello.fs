open System
open System.Reflection
open System.Runtime.InteropServices

let objType = Type.GetTypeFromProgID("Shell.Application")
let shell = Activator.CreateInstance(objType)
let param = [| (0 :> Object); ("Hello, COM(F#) World!" :> Object); (0 :> Object); (36 :> Object) |]
let folder = shell.GetType().InvokeMember("BrowseForFolder", BindingFlags.InvokeMethod, null, shell, param )
if folder <> null then Marshal.ReleaseComObject( folder ) |> ignore
Marshal.ReleaseComObject( shell ) |> ignore
