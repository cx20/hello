import System;
import System.Runtime.InteropServices;
import Shell32;

var ssfWINDOWS = ShellSpecialFolderConstants.ssfWINDOWS;

main();

function main() {
    // NOTE: Avoid `new ShellClass()` (tlbimp may default to IShellDispatch6, 
    // which may be unsupported); use ProgID + IShellDispatch for compatibility.
    
    var shellType : Type = Type.GetTypeFromProgID("Shell.Application");
    var shell : IShellDispatch = IShellDispatch(Activator.CreateInstance(shellType));

    var vRootFolder : Object = int(ssfWINDOWS);
    var folder : Folder = shell.BrowseForFolder(0, "Hello, COM(JScript.NET) World!", 0, vRootFolder);

    if (folder != null) {
        Console.WriteLine("Selected: " + folder.Title);
        Marshal.ReleaseComObject(folder);
    }
    Marshal.ReleaseComObject(shell);
}
