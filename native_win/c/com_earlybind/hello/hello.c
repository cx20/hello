#include <shlobj.h>
 
int main( int argc, char* argv[] )
{
    HRESULT hResult;
    IShellDispatch* pShell;
    VARIANT vRootFolder;
    Folder* pFolder;
 
    CoInitialize( NULL );
 
    CoCreateInstance( &CLSID_Shell, NULL, CLSCTX_INPROC_SERVER, &IID_IShellDispatch, (void**)&pShell );
 
    VariantInit( &vRootFolder );
    vRootFolder.vt = VT_I4;
    vRootFolder.lVal = ssfWINDOWS;
 
    pShell->lpVtbl->BrowseForFolder( (void*)pShell, 0, L"Hello, COM World!", 0, vRootFolder, &pFolder );
    VariantClear( &vRootFolder );
    if ( pFolder != NULL )
    {
        pFolder->lpVtbl->Release( (void*)pFolder );
    }
    pShell->lpVtbl->Release( (void*)pShell );
 
    CoUninitialize();
 
    return 0;
}
