import core.sys.windows.windef;
import core.sys.windows.com;
import core.stdc.string : memset;

pragma(lib, "ole32");
pragma(lib, "oleaut32");

// Constants
enum LOCALE_USER_DEFAULT = 0x0400;
enum DISPATCH_METHOD = 0x1;

immutable GUID IID_NULL = GUID(0, 0, 0, [0, 0, 0, 0, 0, 0, 0, 0]);

// VARENUM definition
enum VARENUM : ushort {
    VT_EMPTY     = 0,
    VT_NULL      = 1,
    VT_I4        = 3,
    VT_BSTR      = 8,
    VT_DISPATCH  = 9,
}

// VARIANT structure (64-bit compatible - 24 bytes)
struct VARIANT {
    VARENUM vt;
    ushort wReserved1;
    ushort wReserved2;
    ushort wReserved3;
    union {
        long llVal;
        int lVal;
        wchar* bstrVal;
        void* punkVal;
        // 16 bytes needed for internal union on 64-bit environment
        ubyte[16] _pad;
    }
}

// DISPPARAMS structure
struct DISPPARAMS {
    VARIANT* rgvarg;
    int* rgdispidNamedArgs;
    uint cArgs;
    uint cNamedArgs;
}

alias DISPID = int;

// OLE Automation function declarations
extern (Windows) {
    HRESULT CLSIDFromProgID(const(wchar)* lpszProgID, CLSID* lpclsid);
    wchar* SysAllocString(const(wchar)* psz);
    void SysFreeString(wchar* bstrString);
}

// Initialize VARIANT - zero clear entire structure
void VariantInit(VARIANT* pvarg) {
    memset(pvarg, 0, VARIANT.sizeof);
}

// IDispatch interface definition
extern (System)
interface IDispatch : IUnknown {
    HRESULT GetTypeInfoCount(uint* pctinfo);
    HRESULT GetTypeInfo(uint iTInfo, uint lcid, void** ppTInfo);
    HRESULT GetIDsOfNames(GUID* riid, wchar** rgszNames, uint cNames, uint lcid, DISPID* rgDispId);
    HRESULT Invoke(DISPID dispIdMember, GUID* riid, uint lcid, ushort wFlags, DISPPARAMS* pDispParams, VARIANT* pVarResult, void* pExcepInfo, uint* puArgErr);
}

immutable GUID IID_IDispatch = GUID(0x00020400, 0x0000, 0x0000, [0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46]);

int main()
{
    HRESULT hr;
    CLSID clsid;
    IDispatch pShell;
    IDispatch pFolder;
    DISPID dispid;

    // Hold strings as variables (explicitly include null terminator)
    static immutable wchar[] progId = "Shell.Application\0"w;
    static immutable wchar[] methodName = "BrowseForFolder\0"w;
    static immutable wchar[] title = "Hello, COM(D) World!\0"w;

    wchar* ptName = cast(wchar*)methodName.ptr;

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
    hr = pShell.GetIDsOfNames(cast(GUID*)&IID_NULL, &ptName, 1, LOCALE_USER_DEFAULT, &dispid);
    if (FAILED(hr)) return 1;

    // Set arguments (stored in reverse order)
    VARIANT[4] varg;

    // varg[0] = RootFolder (VT_I4, 36 = ssfWINDOWS)
    VariantInit(&varg[0]);
    varg[0].vt = VARENUM.VT_I4;
    varg[0].lVal = 36;

    // varg[1] = Options (VT_I4, 0)
    VariantInit(&varg[1]);
    varg[1].vt = VARENUM.VT_I4;
    varg[1].lVal = 0;

    // varg[2] = Title (VT_BSTR)
    VariantInit(&varg[2]);
    varg[2].vt = VARENUM.VT_BSTR;
    varg[2].bstrVal = SysAllocString(title.ptr);

    // varg[3] = Hwnd (VT_I4, 0)
    VariantInit(&varg[3]);
    varg[3].vt = VARENUM.VT_I4;
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
        cast(GUID*)&IID_NULL,
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
    if (vResult.vt == VARENUM.VT_DISPATCH && vResult.punkVal !is null)
    {
        (cast(IUnknown)vResult.punkVal).Release();
    }

    return 0;
}