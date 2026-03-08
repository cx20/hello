#include <atlbase.h>
#include <atlstr.h>
#include <tchar.h>
#include <iostream>

int _tmain(int argc, TCHAR* argv[])
{
    CAtlString str = _T("Hello, C++ (WTL) World!");

#ifdef _UNICODE
    std::wcout << (LPCTSTR)str << std::endl;
#else
    std::cout << (LPCTSTR)str << std::endl;
#endif

    return 0;
}
