#include <afxwin.h> // if use AfxMessageBox() include
#include <tchar.h>

int _tmain(int argc, TCHAR* argv[] )
{
    //::MessageBox( NULL, _T("Hello, Win32 API(C++(MFC)) World!"), _T("Hello, World!"), MB_OK );
    //AfxMessageBox( _T("Hello, Win32 API(C++(MFC)) World!"), MB_OK );
    AfxGetMainWnd()->MessageBox(_T("Hello, Win32 API(C++(MFC)) World!"), _T("Hello, World!"), MB_OK);
 
    return 0;
}