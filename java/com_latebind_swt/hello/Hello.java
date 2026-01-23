import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.internal.win32.TCHAR;
import org.eclipse.swt.internal.ole.win32.COM;
import org.eclipse.swt.internal.ole.win32.GUID;
import org.eclipse.swt.ole.win32.OLE;
import org.eclipse.swt.ole.win32.OleAutomation;
import org.eclipse.swt.ole.win32.Variant;

public class Hello {
    private static final int SSF_WINDOWS = 36;

    public static void main(String[] args) {
        Display display = new Display();
        try {
            GUID clsid = new GUID();
            char[] progId = new TCHAR(0, "Shell.Application", true).chars;
            int hr = COM.CLSIDFromProgID(progId, clsid);
            System.out.printf("CLSIDFromProgID(\"Shell.Application\") hr=0x%08X%n", hr);
            if (hr != COM.S_OK) {
                System.err.println("CLSIDFromProgID failed.");
                return;
            }

            OleAutomation shell = new OleAutomation("Shell.Application");
            try {
                int[] dispIds = shell.getIDsOfNames(new String[] { "BrowseForFolder" });
                int dispIdBrowseForFolder = dispIds[0];

                Variant[] argv = new Variant[] {
                    new Variant(0),                    // hwnd
                    new Variant("Hello, COM World!"),  // title
                    new Variant(0),                    // options
                    new Variant(SSF_WINDOWS)           // rootFolder (ssfWINDOWS=36)
                };

                Variant vFolder = shell.invoke(dispIdBrowseForFolder, argv);
                for (Variant v : argv) v.dispose();

                if (vFolder == null || vFolder.getType() == OLE.VT_EMPTY || vFolder.getType() == OLE.VT_NULL) {
                    System.out.println("Canceled.");
                    return;
                }

                OleAutomation folder = vFolder.getAutomation();
                try {
                    int dispIdSelf = folder.getIDsOfNames(new String[] { "Self" })[0];
                    Variant vSelf = folder.getProperty(dispIdSelf);

                    OleAutomation folderItem = vSelf.getAutomation();
                    try {
                        int dispIdPath = folderItem.getIDsOfNames(new String[] { "Path" })[0];
                        Variant vPath = folderItem.getProperty(dispIdPath);
                        try {
                            System.out.println("Selected: " + vPath.getString());
                        } finally {
                            vPath.dispose();
                        }
                    } finally {
                        folderItem.dispose();
                        vSelf.dispose();
                    }
                } finally {
                    folder.dispose();
                    vFolder.dispose();
                }
            } finally {
                shell.dispose();
            }
        } finally {
            display.dispose();
        }
    }
}
