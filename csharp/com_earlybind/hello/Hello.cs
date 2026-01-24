using System;
using System.Runtime.InteropServices;
using Shell32;

class Hello
{
    static void Main(String[] args)
    {
        // NOTE: Avoid `new Shell()` (tlbimp may default to IShellDispatch6, 
        // which may be unsupported); use ProgID + IShellDispatch for compatibility.

        Type shellType = Type.GetTypeFromProgID("Shell.Application");
        IShellDispatch shell = (IShellDispatch)Activator.CreateInstance(shellType);

        object vRootFolder = (int)ShellSpecialFolderConstants.ssfWINDOWS;
        Folder folder = shell.BrowseForFolder(0, "Hello, COM(C#) World!", 0, vRootFolder);

        if (folder != null)
        {
            Console.WriteLine("Selected: " + folder.Title);
            Marshal.ReleaseComObject(folder);
        }
        Marshal.ReleaseComObject(shell);
    }
}
