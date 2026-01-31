#include <afxdisp.h>

class CFolder : public COleDispatchDriver
{
public:
    CFolder(){}
    CFolder(LPDISPATCH pDispatch) : COleDispatchDriver(pDispatch) {}
    CFolder(const CFolder& dispatchSrc) : COleDispatchDriver(dispatchSrc) {}
public:
    CString get_Title()
    {
        CString result;
        InvokeHelper(0x0, DISPATCH_PROPERTYGET, VT_BSTR, (void*)&result, NULL);
        return result;
    }
};

class CShellDispatch : public COleDispatchDriver
{
public:
    CShellDispatch(){}
    CShellDispatch(LPDISPATCH pDispatch) : COleDispatchDriver(pDispatch) {}
    CShellDispatch(const CShellDispatch& dispatchSrc) : COleDispatchDriver(dispatchSrc) {}
public:
    LPDISPATCH BrowseForFolder(long Hwnd, LPCTSTR Title, long Options, VARIANT& RootFolder)
    {
        LPDISPATCH result;
        static BYTE parms[] = VTS_I4 VTS_BSTR VTS_I4 VTS_VARIANT ;
        InvokeHelper(0x60020003, DISPATCH_METHOD, VT_DISPATCH, (void*)&result, parms, Hwnd, Title, Options, &RootFolder);
        return result;
    }
};

int _tmain(int argc, TCHAR* argv[] )
{
    CoInitialize( NULL );

    CFolder folder;
    CShellDispatch shell;
    shell.CreateDispatch( _T("Shell.Application") );

    COleVariant vRootFolder( (long)ssfWINDOWS );
    folder = shell.BrowseForFolder( 0, _T("Hello, COM(MFC) World!"), 0, vRootFolder );
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