#include <afxdisp.h>

int _tmain(int argc, TCHAR* argv[] )
{
    CoInitialize( NULL );

    COleDispatchDriver shell;
    shell.CreateDispatch( _T("Shell.Application") );

    DISPID  dispid;
    OLECHAR* ptName = L"BrowseForFolder";
    ((LPDISPATCH)shell)->GetIDsOfNames( IID_NULL, &ptName, 1, GetUserDefaultLCID(), &dispid );

    LPDISPATCH pResult;
    COleVariant vRootFolder( 36L );    // ssfWINDOWS
    BYTE parms[] = VTS_I4 VTS_BSTR VTS_I4 VTS_VARIANT;
    shell.InvokeHelper( dispid, DISPATCH_METHOD, VT_DISPATCH, &pResult, parms, 0, _T("Hello, COM(MFC) World!"), 0, &vRootFolder);

    COleDispatchDriver folder = pResult;
    if ( folder != NULL )
    {
        folder.DetachDispatch();
        folder.ReleaseDispatch();
    }
    shell.DetachDispatch();
    shell.ReleaseDispatch();

    CoUninitialize();
    return 0;
}
