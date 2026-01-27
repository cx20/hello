Add-Type -Path ".\Shell32.dll"

$source = @"
using System;
using System.Runtime.InteropServices;
using Shell32;

public class ShellHelper
{
    public static Folder BrowseForFolder(int hwnd, string title, int options, int rootFolder)
    {
        Type shellType = Type.GetTypeFromProgID("Shell.Application");
        IShellDispatch shell = (IShellDispatch)Activator.CreateInstance(shellType);
        
        try
        {
            return shell.BrowseForFolder(hwnd, title, options, rootFolder);
        }
        finally
        {
            Marshal.ReleaseComObject(shell);
        }
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies ".\Shell32.dll"

$ssfWINDOWS = [int][Shell32.ShellSpecialFolderConstants]::ssfWINDOWS

function Main {
    $folder = [ShellHelper]::BrowseForFolder(0, "Hello, COM(PowerShell) World!", 0, $ssfWINDOWS)

    if ($null -ne $folder) {
        Write-Host "Selected: $($folder.Title)"
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($folder) | Out-Null
    }
}

Main