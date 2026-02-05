import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.Memory;
import com.sun.jna.Function;
import com.sun.jna.platform.win32.*;
import com.sun.jna.platform.win32.COM.COMUtils;
import com.sun.jna.platform.win32.Guid.CLSID;
import com.sun.jna.platform.win32.WinNT.HRESULT;
import com.sun.jna.platform.win32.WTypes.BSTR;
import com.sun.jna.ptr.PointerByReference;

public class Hello {
    // IDispatch vtable indices
    static final int ONST_QueryInterface = 0;
    static final int ONST_Release = 2;
    static final int ONST_GetIDsOfNames = 5;
    static final int ONST_Invoke = 6;

    // Invoke flags
    static final int LOCALE_USER_DEFAULT = 0x0400;
    static final int DISPATCH_METHOD = 1;
    static final int DISPATCH_PROPERTYGET = 2;

    // VARIANT constants
    static final short VT_EMPTY = 0;
    static final short VT_NULL = 1;
    static final short VT_I4 = 3;
    static final short VT_BSTR = 8;
    static final short VT_DISPATCH = 9;

    // VARIANT offsets (64-bit)
    static final int VARIANT_SIZE = 24;
    static final int VT_OFFSET = 0;
    static final int VAL_OFFSET = 8;

    // Shell constants
    static final int SSF_WINDOWS = 36;

    public static void main(String[] args) {
        // Initialize COM
        HRESULT hr = Ole32.INSTANCE.CoInitializeEx(Pointer.NULL, Ole32.COINIT_APARTMENTTHREADED);
        if (COMUtils.FAILED(hr)) {
            System.err.printf("CoInitializeEx failed: hr=0x%08X%n", hr.intValue());
            return;
        }

        try {
            // Get CLSID from ProgID
            CLSID.ByReference clsid = new CLSID.ByReference();
            hr = Ole32.INSTANCE.CLSIDFromProgID("Shell.Application", clsid);
            System.out.printf("CLSIDFromProgID(\"Shell.Application\") hr=0x%08X%n", hr.intValue());
            if (COMUtils.FAILED(hr)) {
                System.err.println("CLSIDFromProgID failed.");
                return;
            }

            // Create IDispatch instance
            PointerByReference ppDispatch = new PointerByReference();
            hr = Ole32.INSTANCE.CoCreateInstance(
                clsid,
                null,
                WTypes.CLSCTX_INPROC_SERVER | WTypes.CLSCTX_LOCAL_SERVER,
                com.sun.jna.platform.win32.COM.IDispatch.IID_IDISPATCH,
                ppDispatch
            );

            if (COMUtils.FAILED(hr)) {
                System.err.printf("CoCreateInstance failed: hr=0x%08X%n", hr.intValue());
                return;
            }

            Pointer pShell = ppDispatch.getValue();
            System.out.printf("Shell.Application created: 0x%016X%n", Pointer.nativeValue(pShell));

            try {
                // Get DISPID for "BrowseForFolder"
                int[] dispIdBrowseForFolder = new int[1];
                int hresult = getIDsOfNames(pShell, "BrowseForFolder", dispIdBrowseForFolder);
                if (hresult != COMUtils.S_OK) {
                    System.err.println("Failed to get DISPID for BrowseForFolder");
                    return;
                }
                System.out.println("BrowseForFolder DISPID: " + dispIdBrowseForFolder[0]);

                // Prepare arguments (reverse order for IDispatch::Invoke)
                // argv[0]=hwnd, argv[1]=title, argv[2]=options, argv[3]=rootFolder
                Memory[] variants = new Memory[4];
                for (int i = 0; i < 4; i++) {
                    variants[i] = new Memory(VARIANT_SIZE);
                    variants[i].clear();
                }

                // rootFolder (VT_I4, SSF_WINDOWS=36)
                variants[0].setShort(VT_OFFSET, VT_I4);
                variants[0].setInt(VAL_OFFSET, SSF_WINDOWS);

                // options (VT_I4, 0)
                variants[1].setShort(VT_OFFSET, VT_I4);
                variants[1].setInt(VAL_OFFSET, 0);

                // title (VT_BSTR)
                BSTR bstrTitle = OleAuto.INSTANCE.SysAllocString("Hello, COM World!");
                variants[2].setShort(VT_OFFSET, VT_BSTR);
                variants[2].setPointer(VAL_OFFSET, bstrTitle.getPointer());

                // hwnd (VT_I4, 0)
                variants[3].setShort(VT_OFFSET, VT_I4);
                variants[3].setInt(VAL_OFFSET, 0);

                // Prepare result VARIANT
                Memory pVarResult = new Memory(VARIANT_SIZE);
                pVarResult.clear();

                try {
                    // Call BrowseForFolder
                    hresult = invoke(pShell, dispIdBrowseForFolder[0], DISPATCH_METHOD, variants, pVarResult);
                    System.out.printf("BrowseForFolder hr=0x%08X%n", hresult);

                    if (hresult != COMUtils.S_OK) {
                        System.out.println("BrowseForFolder failed.");
                        return;
                    }

                    short vtResult = pVarResult.getShort(VT_OFFSET);
                    if (vtResult == VT_EMPTY || vtResult == VT_NULL) {
                        System.out.println("Canceled.");
                        return;
                    }

                    if (vtResult == VT_DISPATCH) {
                        Pointer pFolder = pVarResult.getPointer(VAL_OFFSET);
                        if (pFolder == null || Pointer.nativeValue(pFolder) == 0) {
                            System.out.println("Canceled (null folder).");
                            return;
                        }

                        try {
                            // Get Self property
                            int[] dispIdSelf = new int[1];
                            getIDsOfNames(pFolder, "Self", dispIdSelf);

                            Memory pVarSelf = new Memory(VARIANT_SIZE);
                            pVarSelf.clear();
                            hresult = invoke(pFolder, dispIdSelf[0], DISPATCH_PROPERTYGET, null, pVarSelf);

                            if (hresult == COMUtils.S_OK && pVarSelf.getShort(VT_OFFSET) == VT_DISPATCH) {
                                Pointer pFolderItem = pVarSelf.getPointer(VAL_OFFSET);

                                if (pFolderItem != null && Pointer.nativeValue(pFolderItem) != 0) {
                                    try {
                                        // Get Path property
                                        int[] dispIdPath = new int[1];
                                        getIDsOfNames(pFolderItem, "Path", dispIdPath);

                                        Memory pVarPath = new Memory(VARIANT_SIZE);
                                        pVarPath.clear();
                                        hresult = invoke(pFolderItem, dispIdPath[0], DISPATCH_PROPERTYGET, null, pVarPath);

                                        if (hresult == COMUtils.S_OK && pVarPath.getShort(VT_OFFSET) == VT_BSTR) {
                                            Pointer bstrPath = pVarPath.getPointer(VAL_OFFSET);
                                            if (bstrPath != null && Pointer.nativeValue(bstrPath) != 0) {
                                                int len = OleAuto.INSTANCE.SysStringLen(new BSTR(bstrPath));
                                                char[] pathChars = bstrPath.getCharArray(0, len);
                                                System.out.println("Selected: " + new String(pathChars));
                                                OleAuto.INSTANCE.SysFreeString(new BSTR(bstrPath));
                                            }
                                        }
                                    } finally {
                                        release(pFolderItem);
                                    }
                                }
                            }
                        } finally {
                            release(pFolder);
                        }
                    }
                } finally {
                    OleAuto.INSTANCE.SysFreeString(bstrTitle);
                }
            } finally {
                release(pShell);
            }
        } finally {
            Ole32.INSTANCE.CoUninitialize();
        }
    }

    /**
     * Call IUnknown::Release (vtable index 2)
     */
    static void release(Pointer pUnknown) {
        Pointer vtbl = pUnknown.getPointer(0);
        Pointer pfn = vtbl.getPointer(ONST_Release * Native.POINTER_SIZE);
        Function fn = Function.getFunction(pfn, Function.ALT_CONVENTION);
        fn.invoke(int.class, new Object[] { pUnknown });
    }

    /**
     * Call IDispatch::GetIDsOfNames (vtable index 5)
     */
    static int getIDsOfNames(Pointer pDispatch, String name, int[] dispId) {
        Pointer vtbl = pDispatch.getPointer(0);
        Pointer pfn = vtbl.getPointer(ONST_GetIDsOfNames * Native.POINTER_SIZE);
        Function fn = Function.getFunction(pfn, Function.ALT_CONVENTION);

        // IID_NULL
        Memory riid = new Memory(16);
        riid.clear();

        // Name array
        BSTR bstrName = OleAuto.INSTANCE.SysAllocString(name);
        Memory nameMem = new Memory(Native.POINTER_SIZE);
        nameMem.setPointer(0, bstrName.getPointer());

        Memory dispIdMem = new Memory(4);

        int hr = (Integer) fn.invoke(
            int.class,
            new Object[] {
                pDispatch,
                riid,
                nameMem,
                1,
                LOCALE_USER_DEFAULT,
                dispIdMem
            }
        );

        OleAuto.INSTANCE.SysFreeString(bstrName);
        dispId[0] = dispIdMem.getInt(0);
        return hr;
    }

    /**
     * Call IDispatch::Invoke (vtable index 6)
     */
    static int invoke(Pointer pDispatch, int dispId, int wFlags, Memory[] args, Memory pVarResult) {
        Pointer vtbl = pDispatch.getPointer(0);
        Pointer pfn = vtbl.getPointer(ONST_Invoke * Native.POINTER_SIZE);
        Function fn = Function.getFunction(pfn, Function.ALT_CONVENTION);

        // IID_NULL
        Memory riid = new Memory(16);
        riid.clear();

        // DISPPARAMS structure:
        // VARIANTARG *rgvarg;        // Pointer to array of arguments
        // DISPID *rgdispidNamedArgs; // Pointer to array of named argument DISPIDs
        // UINT cArgs;                // Number of arguments
        // UINT cNamedArgs;           // Number of named arguments
        Memory dispParams = new Memory(Native.POINTER_SIZE * 2 + 4 * 2);
        dispParams.clear();

        Memory argsArray = null;
        if (args != null && args.length > 0) {
            // Allocate contiguous memory for VARIANTs
            argsArray = new Memory(VARIANT_SIZE * args.length);
            for (int i = 0; i < args.length; i++) {
                // Copy each VARIANT to contiguous array
                byte[] varData = args[i].getByteArray(0, VARIANT_SIZE);
                argsArray.write(i * VARIANT_SIZE, varData, 0, VARIANT_SIZE);
            }
            dispParams.setPointer(0, argsArray);  // rgvarg
            dispParams.setInt(Native.POINTER_SIZE * 2, args.length);  // cArgs
        }

        return (Integer) fn.invoke(
            int.class,
            new Object[] {
                pDispatch,
                dispId,
                riid,
                LOCALE_USER_DEFAULT,
                wFlags,
                dispParams,
                pVarResult,
                Pointer.NULL,  // pExcepInfo
                Pointer.NULL   // puArgErr
            }
        );
    }
}