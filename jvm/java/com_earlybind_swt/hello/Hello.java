import org.eclipse.swt.internal.ole.win32.COM;
import org.eclipse.swt.internal.ole.win32.DISPPARAMS;
import org.eclipse.swt.internal.ole.win32.GUID;
import org.eclipse.swt.internal.ole.win32.IDispatch;
import org.eclipse.swt.internal.win32.OS;
import org.eclipse.swt.widgets.Display;

public class Hello {
    // CLSID_Shell: {13709620-C279-11CE-A49E-444553540000}
    private static final GUID CLSID_Shell = new GUID();
    static {
        CLSID_Shell.Data1 = 0x13709620;
        CLSID_Shell.Data2 = (short) 0xC279;
        CLSID_Shell.Data3 = (short) 0x11CE;
        CLSID_Shell.Data4 = new byte[] {
            (byte) 0xA4, (byte) 0x9E,
            (byte) 0x44, (byte) 0x45, (byte) 0x53, (byte) 0x54, (byte) 0x00, (byte) 0x00
        };
    }

    // IID_IShellDispatch: {D8F015C0-C278-11CE-A49E-444553540000}
    private static final GUID IID_IShellDispatch = new GUID();
    static {
        IID_IShellDispatch.Data1 = 0xD8F015C0;
        IID_IShellDispatch.Data2 = (short) 0xC278;
        IID_IShellDispatch.Data3 = (short) 0x11CE;
        IID_IShellDispatch.Data4 = new byte[] {
            (byte) 0xA4, (byte) 0x9E,
            (byte) 0x44, (byte) 0x45, (byte) 0x53, (byte) 0x54, (byte) 0x00, (byte) 0x00
        };
    }

    private static final int SSF_WINDOWS = 36;

    // VARIANT size and offsets
    private static final int VARIANT_SIZE = 24;  // 64-bit
    private static final int VT_OFFSET = 0;
    private static final int VAL_OFFSET = 8;

    // IShellDispatch vtable index for BrowseForFolder
    // IUnknown(3) + IDispatch(4) + Application(7) + Parent(8) + NameSpace(9) + BrowseForFolder(10)
    private static final int ONST_BrowseForFolder = 10;

    public static void main(String[] args) {
        Display display = new Display();
        long[] ppShell = new long[1];

        try {
            // CoCreateInstance for IShellDispatch (Early Binding)
            int hr = COM.CoCreateInstance(
                CLSID_Shell,
                0,
                COM.CLSCTX_INPROC_SERVER,
                IID_IShellDispatch,
                ppShell
            );

            if (hr != COM.S_OK) {
                System.err.printf("CoCreateInstance failed: hr=0x%08X%n", hr);
                return;
            }

            long pShell = ppShell[0];
            System.out.printf("IShellDispatch created: 0x%016X%n", pShell);

            try {
                // Prepare VARIANT for RootFolder (VT_I4, ssfWINDOWS=36)
                long pVarRootFolder = OS.GlobalAlloc(OS.GMEM_FIXED | OS.GMEM_ZEROINIT, VARIANT_SIZE);

                // Prepare output VARIANT for result
                long pVarResult = OS.GlobalAlloc(OS.GMEM_FIXED | OS.GMEM_ZEROINIT, VARIANT_SIZE);

                try {
                    // Set vt = VT_I4 (3)
                    short[] vtData = new short[] { COM.VT_I4 };
                    OS.MoveMemory(pVarRootFolder + VT_OFFSET, vtData, 2);
                    // Set lVal = SSF_WINDOWS
                    int[] valData = new int[] { SSF_WINDOWS };
                    OS.MoveMemory(pVarRootFolder + VAL_OFFSET, valData, 4);

                    // Prepare BSTR for title
                    long bstrTitle = COM.SysAllocString("Hello, COM World!".toCharArray());

                    try {
                        // Call IShellDispatch::BrowseForFolder via vtable
                        // Use VtblCall(int, long, long, long, long, long, long)
                        // Parameters: vtableIndex, pShell, Hwnd, bstrTitle, Options, pVarRootFolder, pVarResult
                        hr = COM.VtblCall(
                            ONST_BrowseForFolder,
                            pShell,
                            0L,              // Hwnd
                            bstrTitle,       // Title (BSTR)
                            0L,              // Options
                            pVarRootFolder,  // RootFolder (VARIANT*)
                            pVarResult       // out Folder** (as VARIANT* containing VT_DISPATCH)
                        );

                        System.out.printf("BrowseForFolder hr=0x%08X%n", hr);

                        if (hr == COM.S_OK) {
                            // Read vt from result VARIANT
                            short[] vtResult = new short[1];
                            OS.MoveMemory(vtResult, pVarResult + VT_OFFSET, 2);

                            if (vtResult[0] == COM.VT_DISPATCH) {
                                // Read IDispatch pointer from VARIANT
                                long[] pFolderArr = new long[1];
                                OS.MoveMemory(pFolderArr, pVarResult + VAL_OFFSET, 8);
                                long pFolder = pFolderArr[0];

                                if (pFolder != 0) {
                                    System.out.printf("Folder selected: 0x%016X%n", pFolder);

                                    // Get path using IDispatch::Invoke (Late Binding for Folder object)
                                    printFolderPath(pFolder);

                                    // Release Folder
                                    new IDispatch(pFolder).Release();
                                } else {
                                    System.out.println("Canceled (null folder).");
                                }
                            } else {
                                System.out.println("Canceled or unexpected result type: " + vtResult[0]);
                            }
                        } else {
                            System.out.println("BrowseForFolder failed.");
                        }
                    } finally {
                        COM.SysFreeString(bstrTitle);
                    }
                } finally {
                    OS.GlobalFree(pVarRootFolder);
                    OS.GlobalFree(pVarResult);
                }
            } finally {
                // Release IShellDispatch
                new IDispatch(pShell).Release();
            }
        } finally {
            display.dispose();
        }
    }

    /**
     * Get folder path using IDispatch::Invoke (Late Binding)
     */
    private static void printFolderPath(long pFolder) {
        IDispatch folder = new IDispatch(pFolder);

        try {
            // Get DISPID for "Self" property
            int[] dispIdSelf = new int[1];
            String[] namesSelf = new String[] { "Self" };
            int hr = folder.GetIDsOfNames(new GUID(), namesSelf, 1, COM.LOCALE_USER_DEFAULT, dispIdSelf);
            if (hr != COM.S_OK) {
                System.out.println("Failed to get DISPID for Self");
                return;
            }

            // Invoke to get FolderItem
            long pVarSelf = OS.GlobalAlloc(OS.GMEM_FIXED | OS.GMEM_ZEROINIT, VARIANT_SIZE);
            try {
                DISPPARAMS params = new DISPPARAMS();
                hr = folder.Invoke(dispIdSelf[0], new GUID(), COM.LOCALE_USER_DEFAULT,
                    COM.DISPATCH_PROPERTYGET, params, pVarSelf, null, null);

                if (hr != COM.S_OK) {
                    System.out.println("Failed to get Self property");
                    return;
                }

                // Read FolderItem IDispatch
                short[] vtSelf = new short[1];
                OS.MoveMemory(vtSelf, pVarSelf + VT_OFFSET, 2);

                if (vtSelf[0] == COM.VT_DISPATCH) {
                    long[] pFolderItemArr = new long[1];
                    OS.MoveMemory(pFolderItemArr, pVarSelf + VAL_OFFSET, 8);
                    long pFolderItem = pFolderItemArr[0];

                    if (pFolderItem != 0) {
                        IDispatch folderItem = new IDispatch(pFolderItem);
                        try {
                            // Get DISPID for "Path" property
                            int[] dispIdPath = new int[1];
                            String[] namesPath = new String[] { "Path" };
                            hr = folderItem.GetIDsOfNames(new GUID(), namesPath, 1,
                                COM.LOCALE_USER_DEFAULT, dispIdPath);

                            if (hr == COM.S_OK) {
                                // Invoke to get Path
                                long pVarPath = OS.GlobalAlloc(OS.GMEM_FIXED | OS.GMEM_ZEROINIT, VARIANT_SIZE);
                                try {
                                    DISPPARAMS paramsPath = new DISPPARAMS();
                                    hr = folderItem.Invoke(dispIdPath[0], new GUID(),
                                        COM.LOCALE_USER_DEFAULT, COM.DISPATCH_PROPERTYGET,
                                        paramsPath, pVarPath, null, null);

                                    if (hr == COM.S_OK) {
                                        short[] vtPath = new short[1];
                                        OS.MoveMemory(vtPath, pVarPath + VT_OFFSET, 2);

                                        if (vtPath[0] == COM.VT_BSTR) {
                                            long[] bstrPathArr = new long[1];
                                            OS.MoveMemory(bstrPathArr, pVarPath + VAL_OFFSET, 8);
                                            long bstrPath = bstrPathArr[0];

                                            if (bstrPath != 0) {
                                                int len = COM.SysStringLen(bstrPath);
                                                char[] pathChars = new char[len];
                                                OS.MoveMemory(pathChars, bstrPath, len * 2);
                                                String path = new String(pathChars);
                                                System.out.println("Selected: " + path);
                                                COM.SysFreeString(bstrPath);
                                            }
                                        }
                                    }
                                } finally {
                                    OS.GlobalFree(pVarPath);
                                }
                            }
                        } finally {
                            folderItem.Release();
                        }
                    }
                }
            } finally {
                OS.GlobalFree(pVarSelf);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}