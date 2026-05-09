#include <windows.h>
#include <ole2.h>

void show_com_latebind(void) {
    CLSID clsid;
    IDispatch* pShell = NULL;
    IDispatch* pFolder = NULL;
    DISPID dispid;
    OLECHAR* ptName = L"BrowseForFolder";
    DISPPARAMS param = { NULL, NULL, 0, 0 };
    VARIANT varg[4];
    VARIANT vResult;

    CoInitialize(NULL);

    if (SUCCEEDED(CLSIDFromProgID(L"Shell.Application", &clsid)) &&
        SUCCEEDED(CoCreateInstance(&clsid, NULL, CLSCTX_INPROC_SERVER, &IID_IDispatch, (void**)&pShell)) &&
        pShell != NULL) {
        pShell->lpVtbl->GetIDsOfNames((void*)pShell, &IID_NULL, &ptName, 1, GetUserDefaultLCID(), &dispid);

        VariantInit(&varg[0]);
        varg[0].vt = VT_I4;
        varg[0].lVal = 36L;

        VariantInit(&varg[1]);
        varg[1].vt = VT_I4;
        varg[1].lVal = 0L;

        VariantInit(&varg[2]);
        varg[2].vt = VT_BSTR;
        varg[2].bstrVal = SysAllocString(L"Hello, COM World!");

        VariantInit(&varg[3]);
        varg[3].vt = VT_I4;
        varg[3].lVal = 0L;

        param.cArgs = 4;
        param.rgvarg = varg;

        VariantInit(&vResult);
        pShell->lpVtbl->Invoke((void*)pShell, dispid, &IID_NULL, GetUserDefaultLCID(), DISPATCH_METHOD, &param, &vResult, NULL, NULL);

        VariantClear(&varg[2]);
        pFolder = V_DISPATCH(&vResult);
        VariantClear(&vResult);

        if (pFolder != NULL) {
            pFolder->lpVtbl->Release((void*)pFolder);
        }
        pShell->lpVtbl->Release((void*)pShell);
    }

    CoUninitialize();
}
