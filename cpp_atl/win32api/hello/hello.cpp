#include <atlbase.h>
#include <atlapp.h> // if use AtlMessageBox() include

int _tmain(int argc, TCHAR* argv[] )
{
    //::MessageBox( NULL, _T("Hello, Win32 API(C++(ATL)) World!"), _T("Hello, World!"), MB_OK );
    AtlMessageBox( NULL, _T("Hello, Win32 API(C++(ATL)) World!"), _T("Hello, World!"), MB_OK );
    
    return 0;
}
