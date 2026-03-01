// forked from https://stackoverflow.com/questions/65387849/consume-windows-runtime-apis-from-pure-c
//
// Java + JNA version: Calls WinRT COM interfaces via vtable pointers to show a Toast notification.
//
// Prerequisites:
//   - Windows 10 or later
//   - JNA (jna.jar and jna-platform.jar)
//
// Build & Run:
//   javac -cp jna.jar Hello.java
//   java -cp .;jna.jar Hello

import com.sun.jna.*;
import com.sun.jna.ptr.PointerByReference;
import com.sun.jna.win32.StdCallLibrary;

import java.util.Arrays;
import java.util.List;

public class Hello {

    // ============================================================
    // Constants
    // ============================================================
    static final int RO_INIT_MULTITHREADED = 1;
    static final String APP_ID = "0123456789ABCDEF"; // Dummy App ID
    static final int HSTRING_HEADER_SIZE = 32;        // enough for 64-bit

    // COM vtable indices (IUnknown: 0-2, IInspectable: 3-5, custom: 6+)
    static final int CYCLEQIIDX_QueryInterface = 0;
    static final int CYCLEQIIDX_Release        = 2;

    // ============================================================
    // GUID Structure (matches native GUID layout)
    // ============================================================
    public static class GUID extends Structure {
        public int    Data1;
        public short  Data2;
        public short  Data3;
        public byte[] Data4 = new byte[8];

        public GUID() {}

        public GUID(int d1, short d2, short d3, byte[] d4) {
            Data1 = d1;
            Data2 = d2;
            Data3 = d3;
            System.arraycopy(d4, 0, Data4, 0, 8);
            write(); // sync fields to native memory
        }

        @Override
        protected List<String> getFieldOrder() {
            return Arrays.asList("Data1", "Data2", "Data3", "Data4");
        }
    }

    // ============================================================
    // Interface GUIDs
    // ============================================================
    static final GUID IID_IToastNotificationManagerStatics = new GUID(
        0x50ac103f, (short) 0xd235, (short) 0x4598,
        new byte[]{(byte)0xbb,(byte)0xef,(byte)0x98,(byte)0xfe,
                   (byte)0x4d,(byte)0x1a,(byte)0x3a,(byte)0xd4});

    static final GUID IID_IToastNotificationFactory = new GUID(
        0x04124b20, (short) 0x82c6, (short) 0x4229,
        new byte[]{(byte)0xb1,(byte)0x09,(byte)0xfd,(byte)0x9e,
                   (byte)0xd4,(byte)0x66,(byte)0x2b,(byte)0x53});

    static final GUID IID_IXmlDocument = new GUID(
        0xf7f3a506, (short) 0x1e87, (short) 0x42d6,
        new byte[]{(byte)0xbc,(byte)0xfb,(byte)0xb8,(byte)0xc8,
                   (byte)0x09,(byte)0xfa,(byte)0x54,(byte)0x94});

    static final GUID IID_IXmlDocumentIO = new GUID(
        0x6cd0e74e, (short) 0xee65, (short) 0x4489,
        new byte[]{(byte)0x9e,(byte)0xbf,(byte)0xca,(byte)0x43,
                   (byte)0xe8,(byte)0x7b,(byte)0xa6,(byte)0x37});

    // ============================================================
    // WinRT Runtime Class Names
    // ============================================================
    static final String RC_XmlDocument               = "Windows.Data.Xml.Dom.XmlDocument";
    static final String RC_ToastNotificationManager   = "Windows.UI.Notifications.ToastNotificationManager";
    static final String RC_ToastNotification          = "Windows.UI.Notifications.ToastNotification";

    // ============================================================
    // Native Library: combase.dll (WinRT APIs)
    // ============================================================
    public interface ComBase extends StdCallLibrary {
        ComBase INSTANCE = Native.load("combase", ComBase.class);

        int  RoInitialize(int initType);
        void RoUninitialize();
        int  RoActivateInstance(Pointer activatableClassId, PointerByReference instance);
        int  RoGetActivationFactory(Pointer activatableClassId, GUID iid,
                                    PointerByReference factory);
        int  WindowsCreateStringReference(WString sourceString, int length,
                                          Pointer hstringHeader,
                                          PointerByReference string);
    }

    // ============================================================
    // HSTRING helper (prevents GC of backing memory)
    // ============================================================
    static class HStringRef {
        final WString wstr;    // prevent GC of native string buffer
        final Memory  header;  // HSTRING_HEADER
        final Pointer hstring; // resulting HSTRING handle

        HStringRef(String str) {
            wstr   = new WString(str);
            header = new Memory(HSTRING_HEADER_SIZE);
            PointerByReference phs = new PointerByReference();
            int hr = ComBase.INSTANCE.WindowsCreateStringReference(
                         wstr, str.length(), header, phs);
            if (hr != 0) {
                throw new RuntimeException(String.format(
                    "WindowsCreateStringReference failed: 0x%08X", hr));
            }
            hstring = phs.getValue();
        }
    }

    // ============================================================
    // COM vtable call helpers
    //   COM layout: pInterface -> lpVtbl -> [funcPtr0, funcPtr1, ...]
    //   Each method: HRESULT __stdcall Method(this, args...)
    // ============================================================
    static int comCall(Pointer pInterface, int vtblIndex, Object... extraArgs) {
        Pointer vtbl    = pInterface.getPointer(0);
        Pointer funcPtr = vtbl.getPointer((long) vtblIndex * Native.POINTER_SIZE);
        Function func   = Function.getFunction(funcPtr, Function.ALT_CONVENTION);
        Object[] allArgs = new Object[1 + extraArgs.length];
        allArgs[0] = pInterface; // 'this' pointer
        System.arraycopy(extraArgs, 0, allArgs, 1, extraArgs.length);
        return func.invokeInt(allArgs);
    }

    static void comRelease(Pointer pInterface) {
        if (pInterface != null) {
            comCall(pInterface, CYCLEQIIDX_Release);
        }
    }

    // ============================================================
    // CreateXmlDocumentFromString
    //   Mirrors the C helper: activates XmlDocument, loads XML via IXmlDocumentIO
    // ============================================================
    static Pointer createXmlDocumentFromString(String xmlString) {
        // RoActivateInstance("Windows.Data.Xml.Dom.XmlDocument")
        HStringRef rcXmlDoc = new HStringRef(RC_XmlDocument);
        PointerByReference pInspectable = new PointerByReference();
        int hr = ComBase.INSTANCE.RoActivateInstance(rcXmlDoc.hstring, pInspectable);
        if (hr != 0) {
            throw new RuntimeException(String.format(
                "RoActivateInstance(XmlDocument) failed: 0x%08X", hr));
        }

        // QueryInterface -> IXmlDocument
        PointerByReference pDoc = new PointerByReference();
        comCall(pInspectable.getValue(), CYCLEQIIDX_QueryInterface,
                IID_IXmlDocument, pDoc);
        comRelease(pInspectable.getValue());

        // QueryInterface -> IXmlDocumentIO
        PointerByReference pDocIO = new PointerByReference();
        comCall(pDoc.getValue(), CYCLEQIIDX_QueryInterface,
                IID_IXmlDocumentIO, pDocIO);

        // IXmlDocumentIO::LoadXml(HSTRING) - vtable index 6
        HStringRef xmlHStr = new HStringRef(xmlString);
        hr = comCall(pDocIO.getValue(), 6, xmlHStr.hstring);
        if (hr != 0) {
            throw new RuntimeException(String.format(
                "IXmlDocumentIO::LoadXml failed: 0x%08X", hr));
        }
        comRelease(pDocIO.getValue());

        return pDoc.getValue();
    }

    // ============================================================
    // Main
    // ============================================================
    public static void main(String[] args) {
        int hr = ComBase.INSTANCE.RoInitialize(RO_INIT_MULTITHREADED);
        if (hr != 0 && hr != 1) { // S_OK or S_FALSE
            System.err.printf("RoInitialize failed: 0x%08X%n", hr);
            return;
        }

        Pointer inputXml     = null;
        Pointer toastStatics = null;
        Pointer notifier     = null;
        Pointer notifFactory = null;
        Pointer toast        = null;

        try {
            // --- 1. Create XML document for the toast ---
            String toastXml =
                "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n" +
                "  <visual>\r\n" +
                "    <binding template=\"ToastGeneric\">\r\n" +
                "      <text><![CDATA[Hello, WinRT World!]]></text>\r\n" +
                "    </binding>\r\n" +
                "  </visual>\r\n" +
                "  <audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n" +
                "</toast>\r\n";
            inputXml = createXmlDocumentFromString(toastXml);

            // --- 2. Get IToastNotificationManagerStatics ---
            HStringRef rcToastMgr = new HStringRef(RC_ToastNotificationManager);
            PointerByReference pToastStatics = new PointerByReference();
            hr = ComBase.INSTANCE.RoGetActivationFactory(
                     rcToastMgr.hstring,
                     IID_IToastNotificationManagerStatics,
                     pToastStatics);
            if (hr != 0) {
                throw new RuntimeException(String.format(
                    "RoGetActivationFactory(ToastNotificationManager) failed: 0x%08X", hr));
            }
            toastStatics = pToastStatics.getValue();

            // --- 3. CreateToastNotifierWithId - vtable index 7 ---
            //   IToastNotificationManagerStatics vtable:
            //     6: CreateToastNotifier()
            //     7: CreateToastNotifierWithId(HSTRING appId, IToastNotifier** result)
            HStringRef appIdStr = new HStringRef(APP_ID);
            PointerByReference pNotifier = new PointerByReference();
            hr = comCall(toastStatics, 7, appIdStr.hstring, pNotifier);
            if (hr != 0) {
                throw new RuntimeException(String.format(
                    "CreateToastNotifierWithId failed: 0x%08X", hr));
            }
            notifier = pNotifier.getValue();

            // --- 4. Get IToastNotificationFactory ---
            HStringRef rcToastNotif = new HStringRef(RC_ToastNotification);
            PointerByReference pNotifFactory = new PointerByReference();
            hr = ComBase.INSTANCE.RoGetActivationFactory(
                     rcToastNotif.hstring,
                     IID_IToastNotificationFactory,
                     pNotifFactory);
            if (hr != 0) {
                throw new RuntimeException(String.format(
                    "RoGetActivationFactory(ToastNotification) failed: 0x%08X", hr));
            }
            notifFactory = pNotifFactory.getValue();

            // --- 5. CreateToastNotification - vtable index 6 ---
            //   IToastNotificationFactory vtable:
            //     6: CreateToastNotification(IXmlDocument* content, IToastNotification** value)
            PointerByReference pToast = new PointerByReference();
            hr = comCall(notifFactory, 6, inputXml, pToast);
            if (hr != 0) {
                throw new RuntimeException(String.format(
                    "CreateToastNotification failed: 0x%08X", hr));
            }
            toast = pToast.getValue();

            // --- 6. Show the toast - vtable index 6 ---
            //   IToastNotifier vtable:
            //     6: Show(IToastNotification* notification)
            hr = comCall(notifier, 6, toast);
            if (hr != 0) {
                throw new RuntimeException(String.format(
                    "IToastNotifier::Show failed: 0x%08X", hr));
            }

            System.out.println("Toast notification shown!");
            Thread.sleep(1); // brief pause (matches C version's Sleep(1))

        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        } finally {
            // Cleanup (Release all COM objects)
            comRelease(toast);
            comRelease(notifFactory);
            comRelease(notifier);
            comRelease(toastStatics);
            comRelease(inputXml);
            ComBase.INSTANCE.RoUninitialize();
        }
    }
}
