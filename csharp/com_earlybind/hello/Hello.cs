using System;
using System.Runtime.InteropServices;
using Shell32;

class Hello
{
    static void Main(String[] args)
    {
        Shell shell = new Shell();
        Object vRootFolder = (long)ShellSpecialFolderConstants.ssfWINDOWS;
        Folder folder = shell.BrowseForFolder(0, "Hello, COM(C#) World!", 0, vRootFolder);
        if (folder != null)
        {
            Marshal.ReleaseComObject(folder);
        }
        Marshal.ReleaseComObject(shell);
    }
}
