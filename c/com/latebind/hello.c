#include <ole2.h>
 
int main( int argc, char* argv[] )
{
    CLSID clsid;
    IDispatch* pShell;
    IDispatch* pFolder;
    DISPID dispid;
    OLECHAR* ptName = L"BrowseForFolder";
    DISPPARAMS param = { NULL, NULL, 0, 0 };
    VARIANT varg[4];
    VARIANT vResult;
 
    CoInitialize( NULL );
 
    CLSIDFromProgID(L"Shell.Application", &clsid );
    CoCreateInstance( &clsid, NULL, CLSCTX_INPROC_SERVER, &IID_IDispatch, (void**)&pShell);
    pShell->lpVtbl->GetIDsOfNames( (void*)pShell, &IID_NULL, &ptName, 1, GetUserDefaultLCID(), &dispid );
 
    VariantInit( &varg[0] );
    varg[0].vt = VT_I4;
    varg[0].lVal = 36L;  /* ssfWINDOWS */
 
    VariantInit( &varg[1] );
    varg[1].vt = VT_I4;
    varg[1].lVal = 0L;
 
    VariantInit( &varg[2] );
    varg[2].vt = VT_BSTR;
    varg[2].bstrVal = SysAllocString(L"Hello, COM World!"); 
 
    VariantInit( &varg[3] );
    varg[3].vt = VT_I4;
    varg[3].lVal = 0L;
 
    param.cArgs = 4;
    param.rgvarg = varg;
 
    pShell->lpVtbl->Invoke( (void*)pShell, dispid, &IID_NULL, GetUserDefaultLCID(), DISPATCH_METHOD, &param, &vResult, NULL, NULL );
 
    VariantInit( &varg[0] );
    VariantInit( &varg[1] );
    VariantInit( &varg[2] );
    VariantInit( &varg[3] );
 
    pFolder = V_DISPATCH( &vResult );
    if ( pFolder != NULL )
    {
        pFolder->lpVtbl->Release( (void*)pFolder );
    }
    pShell->lpVtbl->Release( (void*)pShell );
 
    CoUninitialize();
 
    return 0;
}
