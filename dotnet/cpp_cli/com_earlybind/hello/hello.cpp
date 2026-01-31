#include <shlobj.h>

int main( int argc, char* argv[] )
{
    CoInitialize( NULL );

    IShellDispatch* pShell;
    CoCreateInstance( CLSID_Shell, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pShell) );

    VARIANT vRootFolder;
    VariantInit( &vRootFolder );
    vRootFolder.vt = VT_I4;
    vRootFolder.lVal = ssfWINDOWS;

    Folder* pFolder;
    pShell->BrowseForFolder( 0, L"Hello, COM(C++/CLI) World!", 0, vRootFolder, &pFolder );
    VariantClear( &vRootFolder );
    if ( pFolder != NULL )
    {
        pFolder->Release();
    }
    pShell->Release();

    CoUninitialize();

    return 0;
}
