import System;
import System.Runtime.InteropServices;

var ssfWINDOWS = 36

main();

function main() {
    var shell = new ActiveXObject("Shell.Application");
    var folder = shell.BrowseForFolder( 0, "Hello, COM(JScript.NET) World!", 0, ssfWINDOWS );
    if ( folder != null )
    {
        Marshal.ReleaseComObject( folder );
    }
    Marshal.ReleaseComObject( shell );
}
