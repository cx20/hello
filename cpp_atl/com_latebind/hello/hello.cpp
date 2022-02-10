#include <atlbase.h>

int _tmain(int argc, TCHAR* argv[] )
{
    CoInitialize( NULL );

    CComPtr<IDispatch> pShell;
    pShell.CoCreateInstance( L"Shell.Application" );

    DISPPARAMS param = { NULL, NULL, 0, 0 };
    CComVariant varg[4];
    varg[0] = 36L;  // VT_I4 ssfWINDOWS 
    varg[1] = 0L;   // VT_I4
    varg[2] = L"Hello, COM(ATL) World!"; //  VT_BSTR
    varg[3] = 0L;   // VT_I4

    CComVariant vResult;
    pShell.InvokeN(L"BrowseForFolder", varg, 4, &vResult );

    CComPtr<IDispatch> pFolder = vResult.pdispVal;
    if ( pFolder != NULL )
    {
        pFolder = NULL;
    }
    pShell = NULL;

    CoUninitialize();

    return 0;
}
