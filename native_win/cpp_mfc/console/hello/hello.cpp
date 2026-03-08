#include <afx.h>
#include <tchar.h>
#include <iostream>

int _tmain(int argc, TCHAR* argv[])
{
    CString message = _T("Hello, C++ (MFC) World!");

#ifdef _UNICODE
    std::wcout << (LPCTSTR)message << std::endl;
#else
    std::cout << (LPCTSTR)message << std::endl;
#endif

    return 0;
}