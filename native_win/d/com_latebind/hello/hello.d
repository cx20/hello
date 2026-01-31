import core.sys.windows.windef;
import core.sys.windows.com;
import core.sys.windows.oaidl;
import core.sys.windows.oleauto;

pragma(lib, "ole32");
pragma(lib, "oleaut32");

// Constants not defined in standard library
enum LOCALE_USER_DEFAULT = 0x0400;
enum DISPATCH_METHOD = 0x1;

// VARTYPE constants
enum : ushort {
    VT_EMPTY    = 0,
    VT_NULL     = 1,
    VT_I4       = 3,
    VT_BSTR     = 8,
    VT_DISPATCH = 9,
}

immutable GUID IID_NULL = GUID(0, 0, 0, [0, 0, 0, 0, 0, 0, 0, 0]);

// CLSIDFromProgID is not in standard library
extern (Windows) HRESULT CLSIDFromProgID(const(wchar)* lpszProgID, CLSID* lpclsid);

int main()
{
    HRESULT hr;
    CLSID clsid;
    IDispatch pShell;
    DISPID dispid;

    // Hold strings as variables (explicitly include null terminator)
    static immutable wchar[] progId = "Shell.Application\0"w;
    static immutable wchar[] methodName = "BrowseForFolder\0"w;
    static immutable wchar[] title = "Hello, COM(D) World!\0"w;

    LPOLESTR ptName = cast(LPOLESTR)methodName.ptr;

    hr = CoInitialize(null);
    if (FAILED(hr)) return 1;

    scope(exit) CoUninitialize();

    // Get CLSID from ProgID
    hr = CLSIDFromProgID(progId.ptr, &clsid);
    if (FAILED(hr)) return 1;

    // Get IDispatch interface
    hr = CoCreateInstance(&clsid, null, CLSCTX_INPROC_SERVER, &IID_IDispatch, cast(void**)&pShell);
    if (FAILED(hr)) return 1;

    scope(exit) pShell.Release();

    // Get DISPID from method name
    hr = pShell.GetIDsOfNames(&IID_NULL, &ptName, 1, LOCALE_USER_DEFAULT, &dispid);
    if (FAILED(hr)) return 1;

    // Set arguments (stored in reverse order)
    VARIANT[4] varg;

    // varg[0] = RootFolder (VT_I4, 36 = ssfWINDOWS)
    VariantInit(&varg[0]);
    varg[0].vt = VT_I4;
    varg[0].lVal = 36;

    // varg[1] = Options (VT_I4, 0)
    VariantInit(&varg[1]);
    varg[1].vt = VT_I4;
    varg[1].lVal = 0;

    // varg[2] = Title (VT_BSTR)
    VariantInit(&varg[2]);
    varg[2].vt = VT_BSTR;
    varg[2].bstrVal = SysAllocString(title.ptr);

    // varg[3] = Hwnd (VT_I4, 0)
    VariantInit(&varg[3]);
    varg[3].vt = VT_I4;
    varg[3].lVal = 0;

    // Set DISPPARAMS
    DISPPARAMS param;
    param.rgvarg = varg.ptr;
    param.rgdispidNamedArgs = null;
    param.cArgs = 4;
    param.cNamedArgs = 0;

    // Invoke method
    VARIANT vResult;
    VariantInit(&vResult);

    hr = pShell.Invoke(
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_METHOD,
        &param,
        &vResult,
        null,
        null
    );

    // Free BSTR
    SysFreeString(varg[2].bstrVal);

    // Release result Folder object
    if (vResult.vt == VT_DISPATCH && vResult.punkVal !is null)
    {
        vResult.punkVal.Release();
    }

    return 0;
}
