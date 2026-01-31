#include <atlbase.h>
#include <shlobj.h>

int _tmain(int argc, TCHAR* argv[] )
{
    CoInitialize( NULL );

    CComPtr<Folder> pFolder;
    CComPtr<IShellDispatch> pShell;
    pShell.CoCreateInstance( CLSID_Shell );

    CComVariant vRootFolder( ssfWINDOWS );
    pShell->BrowseForFolder( 0, L"Hello, COM(WTL) World!", 0, vRootFolder, &pFolder );
    if ( pFolder != NULL )
    {
        pFolder = NULL;
    }
    pShell = NULL;

    CoUninitialize();

    return 0;
}
