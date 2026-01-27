open System
open System.Runtime.InteropServices
open Shell32

[<EntryPoint>]
let main args =
    // NOTE: Avoid `new Shell()` (tlbimp may default to IShellDispatch6, 
    // which may be unsupported); use ProgID + IShellDispatch for compatibility.
    
    let shellType = Type.GetTypeFromProgID("Shell.Application")
    let shell = Activator.CreateInstance(shellType) :?> IShellDispatch

    let vRootFolder = box (int ShellSpecialFolderConstants.ssfWINDOWS)
    let folder = shell.BrowseForFolder(0, "Hello, COM(F#) World!", 0, vRootFolder)

    if not (isNull folder) then
        printfn "Selected: %s" folder.Title
        Marshal.ReleaseComObject(folder) |> ignore

    Marshal.ReleaseComObject(shell) |> ignore
    0
