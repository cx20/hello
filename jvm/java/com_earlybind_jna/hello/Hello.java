import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Memory;
import com.sun.jna.platform.win32.*;
import com.sun.jna.platform.win32.COM.*;
import com.sun.jna.platform.win32.Guid.CLSID;
import com.sun.jna.platform.win32.Guid.IID;
import com.sun.jna.platform.win32.Guid.REFIID;
import com.sun.jna.platform.win32.Variant.VARIANT;
import com.sun.jna.platform.win32.WTypes.BSTR;
import com.sun.jna.platform.win32.WinNT.HRESULT;
import com.sun.jna.platform.win32.WinDef.*;
import com.sun.jna.ptr.PointerByReference;

public class Hello {
    // CLSID_Shell: {13709620-C279-11CE-A49E-444553540000}
    private static final CLSID CLSID_Shell = new CLSID("13709620-C279-11CE-A49E-444553540000");

    // IID_IShellDispatch: {D8F015C0-C278-11CE-A49E-444553540000}
    private static final IID IID_IShellDispatch = new IID("D8F015C0-C278-11CE-A49E-444553540000");

    private static final int SSF_WINDOWS = 36;

    // IShellDispatch vtable index for BrowseForFolder
    // IUnknown(3) + IDispatch(4) + Application(7) + Parent(8) + NameSpace(9) + BrowseForFolder(10)
    private static final int ONST_BrowseForFolder = 10;

    // VARIANT offsets (64-bit)
    private static final int VARIANT_SIZE = 24;
    private static final int VT_OFFSET = 0;
    private static final int VAL_OFFSET = 8;

    public static void main(String[] args) {
        // Initialize COM
        HRESULT hr = Ole32.INSTANCE.CoInitializeEx(Pointer.NULL, Ole32.COINIT_APARTMENTTHREADED);
        if (COMUtils.FAILED(hr)) {
            System.err.printf("CoInitializeEx failed: hr=0x%08X%n", hr.intValue());
            return;
        }

        try {
            // CoCreateInstance for IShellDispatch
            PointerByReference ppShell = new PointerByReference();
            hr = Ole32.INSTANCE.CoCreateInstance(
                CLSID_Shell,
                null,
                WTypes.CLSCTX_INPROC_SERVER,
                IID_IShellDispatch,
                ppShell
            );

            if (COMUtils.FAILED(hr)) {
                System.err.printf("CoCreateInstance failed: hr=0x%08X%n", hr.intValue());
                return;
            }

            Pointer pShell = ppShell.getValue();
            System.out.printf("IShellDispatch created: 0x%016X%n", Pointer.nativeValue(pShell));

            try {
                // Prepare VARIANT for RootFolder (VT_I4, ssfWINDOWS=36)
                Memory pVarRootFolder = new Memory(VARIANT_SIZE);
                pVarRootFolder.clear();
                pVarRootFolder.setShort(VT_OFFSET, (short) Variant.VT_I4);
                pVarRootFolder.setInt(VAL_OFFSET, SSF_WINDOWS);

                // Prepare output VARIANT for result
                Memory pVarResult = new Memory(VARIANT_SIZE);
                pVarResult.clear();

                // Prepare BSTR for title
                BSTR bstrTitle = OleAuto.INSTANCE.SysAllocString("Hello, COM World!");

                try {
                    // Call IShellDispatch::BrowseForFolder via vtable (Early Binding)
                    // vtable layout: pointer to array of function pointers
                    Pointer vtbl = pShell.getPointer(0);
                    Pointer pfnBrowseForFolder = vtbl.getPointer(ONST_BrowseForFolder * Native.POINTER_SIZE);

                    // BrowseForFolder(Hwnd, Title, Options, RootFolder, *ppFolder)
                    // Returns HRESULT, last parameter is output VARIANT containing IDispatch
                    com.sun.jna.Function fn = com.sun.jna.Function.getFunction(pfnBrowseForFolder, com.sun.jna.Function.ALT_CONVENTION);
                    int hresult = (Integer) fn.invoke(
                        int.class,
                        new Object[] {
                            pShell,                          // this
                            new LONG(0),                     // Hwnd
                            bstrTitle.getPointer(),          // Title (BSTR)
                            new LONG(0),                     // Options
                            pVarRootFolder,                  // RootFolder (VARIANT*)
                            pVarResult                       // out Folder** (as VARIANT*)
                        }
                    );

                    System.out.printf("BrowseForFolder hr=0x%08X%n", hresult);

                    if (hresult == COMUtils.S_OK) {
                        // Read vt from result VARIANT
                        short vtResult = pVarResult.getShort(VT_OFFSET);

                        if (vtResult == Variant.VT_DISPATCH) {
                            // Read IDispatch pointer from VARIANT
                            Pointer pFolder = pVarResult.getPointer(VAL_OFFSET);

                            if (pFolder != null && Pointer.nativeValue(pFolder) != 0) {
                                System.out.printf("Folder selected: 0x%016X%n", Pointer.nativeValue(pFolder));

                                // Get path using IDispatch::Invoke (Late Binding)
                                printFolderPath(pFolder);

                                // Release Folder
                                release(pFolder);
                            } else {
                                System.out.println("Canceled (null folder).");
                            }
                        } else {
                            System.out.println("Canceled or unexpected result type: " + vtResult);
                        }
                    } else {
                        System.out.println("BrowseForFolder failed.");
                    }
                } finally {
                    OleAuto.INSTANCE.SysFreeString(bstrTitle);
                }
            } finally {
                // Release IShellDispatch
                release(pShell);
            }
        } finally {
            Ole32.INSTANCE.CoUninitialize();
        }
    }

    /**
     * Call IUnknown::Release
     */
    private static void release(Pointer pUnknown) {
        // IUnknown::Release is at vtable index 2
        Pointer vtbl = pUnknown.getPointer(0);
        Pointer pfnRelease = vtbl.getPointer(2 * Native.POINTER_SIZE);
        com.sun.jna.Function fn = com.sun.jna.Function.getFunction(pfnRelease, com.sun.jna.Function.ALT_CONVENTION);
        fn.invoke(int.class, new Object[] { pUnknown });
    }

    /**
     * Call IDispatch::GetIDsOfNames
     */
    private static int getIDsOfNames(Pointer pDispatch, String name, int[] dispId) {
        // IDispatch::GetIDsOfNames is at vtable index 5
        Pointer vtbl = pDispatch.getPointer(0);
        Pointer pfn = vtbl.getPointer(5 * Native.POINTER_SIZE);
        com.sun.jna.Function fn = com.sun.jna.Function.getFunction(pfn, com.sun.jna.Function.ALT_CONVENTION);

        // Prepare IID_NULL
        Memory riid = new Memory(16);
        riid.clear();

        // Prepare name array (LPOLESTR*)
        Memory nameMem = new Memory(Native.POINTER_SIZE);
        BSTR bstrName = OleAuto.INSTANCE.SysAllocString(name);
        nameMem.setPointer(0, bstrName.getPointer());

        // Prepare output
        Memory dispIdMem = new Memory(4);

        int hr = (Integer) fn.invoke(
            int.class,
            new Object[] {
                pDispatch,           // this
                riid,                // riid (IID_NULL)
                nameMem,             // rgszNames
                1,                   // cNames
                0x0400,              // lcid (LOCALE_USER_DEFAULT)
                dispIdMem            // rgDispId
            }
        );

        OleAuto.INSTANCE.SysFreeString(bstrName);
        dispId[0] = dispIdMem.getInt(0);
        return hr;
    }

    /**
     * Call IDispatch::Invoke for property get
     */
    private static int invokePropertyGet(Pointer pDispatch, int dispId, Memory pVarResult) {
        // IDispatch::Invoke is at vtable index 6
        Pointer vtbl = pDispatch.getPointer(0);
        Pointer pfn = vtbl.getPointer(6 * Native.POINTER_SIZE);
        com.sun.jna.Function fn = com.sun.jna.Function.getFunction(pfn, com.sun.jna.Function.ALT_CONVENTION);

        // Prepare IID_NULL
        Memory riid = new Memory(16);
        riid.clear();

        // Prepare DISPPARAMS (empty for property get)
        Memory dispParams = new Memory(Native.POINTER_SIZE * 2 + 4 * 2);
        dispParams.clear();

        return (Integer) fn.invoke(
            int.class,
            new Object[] {
                pDispatch,           // this
                dispId,              // dispIdMember
                riid,                // riid
                0x0400,              // lcid (LOCALE_USER_DEFAULT)
                2,                   // wFlags (DISPATCH_PROPERTYGET)
                dispParams,          // pDispParams
                pVarResult,          // pVarResult
                Pointer.NULL,        // pExcepInfo
                Pointer.NULL         // puArgErr
            }
        );
    }

    /**
     * Get folder path using IDispatch::Invoke (Late Binding)
     */
    private static void printFolderPath(Pointer pFolder) {
        try {
            // Get DISPID for "Self" property
            int[] dispIdSelf = new int[1];
            int hr = getIDsOfNames(pFolder, "Self", dispIdSelf);
            if (hr != COMUtils.S_OK) {
                System.out.println("Failed to get DISPID for Self");
                return;
            }

            // Invoke to get FolderItem
            Memory pVarSelf = new Memory(VARIANT_SIZE);
            pVarSelf.clear();

            hr = invokePropertyGet(pFolder, dispIdSelf[0], pVarSelf);
            if (hr != COMUtils.S_OK) {
                System.out.println("Failed to get Self property");
                return;
            }

            // Read FolderItem IDispatch
            short vtSelf = pVarSelf.getShort(VT_OFFSET);
            if (vtSelf == Variant.VT_DISPATCH) {
                Pointer pFolderItem = pVarSelf.getPointer(VAL_OFFSET);

                if (pFolderItem != null && Pointer.nativeValue(pFolderItem) != 0) {
                    try {
                        // Get DISPID for "Path" property
                        int[] dispIdPath = new int[1];
                        hr = getIDsOfNames(pFolderItem, "Path", dispIdPath);

                        if (hr == COMUtils.S_OK) {
                            // Invoke to get Path
                            Memory pVarPath = new Memory(VARIANT_SIZE);
                            pVarPath.clear();

                            hr = invokePropertyGet(pFolderItem, dispIdPath[0], pVarPath);
                            if (hr == COMUtils.S_OK) {
                                short vtPath = pVarPath.getShort(VT_OFFSET);

                                if (vtPath == Variant.VT_BSTR) {
                                    Pointer bstrPath = pVarPath.getPointer(VAL_OFFSET);

                                    if (bstrPath != null && Pointer.nativeValue(bstrPath) != 0) {
                                        int len = OleAuto.INSTANCE.SysStringLen(new BSTR(bstrPath));
                                        char[] pathChars = bstrPath.getCharArray(0, len);
                                        String path = new String(pathChars);
                                        System.out.println("Selected: " + path);
                                        OleAuto.INSTANCE.SysFreeString(new BSTR(bstrPath));
                                    }
                                }
                            }
                        }
                    } finally {
                        release(pFolderItem);
                    }
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}