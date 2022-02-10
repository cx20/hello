#import "shell32.dll"
using namespace Shell32;

int main( int argc, char* argv[] )
{
    CoInitialize( NULL );

    IShellDispatchPtr pShell("Shell.Application");
    FolderPtr pFolder = NULL;

    _variant_t vRootFolder( ssfWINDOWS );
    pFolder = pShell->BrowseForFolder( 0, L"Hello, COM(#import) World!", 0, vRootFolder );
    if ( pFolder != NULL )
    {
        pFolder = NULL;
    }
    pShell = NULL;

    CoUninitialize();

    return 0;
}
