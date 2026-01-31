#include <windows.h>
#include <tchar.h>

int _tmain( int argc, TCHAR* argv[] )
{
    MessageBox( NULL, _T("Hello, Win32 API World!"), _T("Hello, World!"), MB_OK );
    return 0;
}
