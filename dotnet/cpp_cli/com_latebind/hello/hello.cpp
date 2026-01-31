#include <ole2.h>

int main( int argc, char* argv[] )
{
    CoInitialize( NULL );

    CLSID clsid;
    CLSIDFromProgID( L"Shell.Application", &clsid );
    IDispatch* pShell;
    CoCreateInstance( clsid, NULL, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pShell) );

    DISPID dispid;
    OLECHAR* ptName = L"BrowseForFolder";
    pShell->GetIDsOfNames( IID_NULL, &ptName, 1, GetUserDefaultLCID(), &dispid );

    DISPPARAMS param = { NULL, NULL, 0, 0 };
    VARIANT varg[4];
    VariantInit( &varg[0] );
    varg[0].vt = VT_I4;
    varg[0].lVal = 36L;  // ssfWINDOWS 

    VariantInit( &varg[1] );
    varg[1].vt = VT_I4;
    varg[1].lVal = 0L;

    VariantInit( &varg[2] );
    varg[2].vt = VT_BSTR;
    varg[2].bstrVal = SysAllocString(L"Hello, COM(C++/CLI) World!"); 

    VariantInit( &varg[3] );
    varg[3].vt = VT_I4;
    varg[3].lVal = 0L;

    param.cArgs = 4;
    param.rgvarg = varg;

    VARIANT vResult;
    pShell->Invoke( dispid, IID_NULL, GetUserDefaultLCID(), DISPATCH_METHOD, &param, &vResult, NULL, NULL );

    VariantClear( &varg[0] );
    VariantClear( &varg[1] );
    VariantClear( &varg[2] );
    VariantClear( &varg[3] );

    IDispatch* pFolder = V_DISPATCH( &vResult );
    if ( pFolder != NULL )
    {
        pFolder->Release();
    }
    pShell->Release();

    CoUninitialize();
}
