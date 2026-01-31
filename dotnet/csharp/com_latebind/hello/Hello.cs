using System;
using System.Reflection;
using System.Runtime.InteropServices;

class Hello
{
    static void Main(String[] args)
    {
        Type objType = Type.GetTypeFromProgID("Shell.Application"); 
        Object shell = Activator.CreateInstance(objType);
        Object[] param = { 0, "Hello, COM(C#) World!", 0, 36 };
        Object folder = shell.GetType().InvokeMember( 
            "BrowseForFolder", BindingFlags.InvokeMethod, null, shell, param );
        if (folder != null)
        {
            Marshal.ReleaseComObject(folder);
        }
        Marshal.ReleaseComObject(shell);
    }
}
