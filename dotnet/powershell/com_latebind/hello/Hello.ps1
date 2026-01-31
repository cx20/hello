$ssfWINDOWS = 36

function Main() {
    $shell = new-object -comobject Shell.Application
    $folder = $shell.BrowseForFolder( 0, "Hello, COM(PowerShell) World!", 0, $ssfWINDOWS )
}

Main
