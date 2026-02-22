"""
WinRT Toast Notification (ctypes only, no external libraries)

This sample demonstrates how to show a Windows Toast Notification
using only Python's ctypes without any external packages.
"""
import ctypes
import os
import sys
from ctypes import wintypes


# ============================================================
# DLLs
# ============================================================
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
combase = ctypes.WinDLL("combase", use_last_error=True)
shell32 = ctypes.WinDLL("shell32", use_last_error=True)

# Add HRESULT and SIZE_T if not defined (Python version compatibility)
if not hasattr(wintypes, "HRESULT"):
    wintypes.HRESULT = ctypes.c_long
if not hasattr(wintypes, "SIZE_T"):
    wintypes.SIZE_T = ctypes.c_size_t

# ============================================================
# Debug output
# ============================================================
kernel32.OutputDebugStringW.restype = None
kernel32.OutputDebugStringW.argtypes = (wintypes.LPCWSTR,)

kernel32.Sleep.restype = None
kernel32.Sleep.argtypes = (wintypes.DWORD,)

shell32.SetCurrentProcessExplicitAppUserModelID.restype = wintypes.HRESULT
shell32.SetCurrentProcessExplicitAppUserModelID.argtypes = (wintypes.LPCWSTR,)

def debug_print(msg: str):
    """Output debug message to DebugView and console"""
    kernel32.OutputDebugStringW(f"[PyToast] {msg}\n")
    print(f"[PyToast] {msg}")

# ============================================================
# Constants
# ============================================================
RO_INIT_MULTITHREADED = 1
S_OK = 0
S_FALSE = 1

# App ID - Using dummy App ID (same as C version)
APP_ID = "0123456789ABCDEF"

# Runtime Class Names (from Windows SDK headers)
RuntimeClass_Windows_Data_Xml_Dom_XmlDocument = "Windows.Data.Xml.Dom.XmlDocument"
RuntimeClass_Windows_UI_Notifications_ToastNotificationManager = "Windows.UI.Notifications.ToastNotificationManager"
RuntimeClass_Windows_UI_Notifications_ToastNotification = "Windows.UI.Notifications.ToastNotification"

# ============================================================
# GUID structure
# ============================================================
class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def make_guid(data1, data2, data3, *data4_bytes) -> GUID:
    """Create GUID from components (matching DEFINE_GUID format)"""
    g = GUID()
    g.Data1 = data1
    g.Data2 = data2
    g.Data3 = data3
    for i, b in enumerate(data4_bytes):
        g.Data4[i] = b
    return g

# GUIDs for WinRT interfaces
IID_IToastNotificationManagerStatics = make_guid(
    0x50ac103f, 0xd235, 0x4598, 0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4
)
IID_IToastNotificationFactory = make_guid(
    0x04124b20, 0x82c6, 0x4229, 0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53
)
IID_IXmlDocument = make_guid(
    0xf7f3a506, 0x1e87, 0x42d6, 0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94
)
IID_IXmlDocumentIO = make_guid(
    0x6cd0e74e, 0xee65, 0x4489, 0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37
)

# ============================================================
# HSTRING types
# ============================================================
HSTRING = ctypes.c_void_p

class HSTRING_HEADER(ctypes.Structure):
    """Opaque header structure for HSTRING references"""
    _fields_ = [
        ("Reserved", ctypes.c_void_p * 5),
    ]

# ============================================================
# WinRT function prototypes
# ============================================================
# HRESULT RoInitialize(RO_INIT_TYPE initType)
RoInitialize = combase.RoInitialize
RoInitialize.restype = wintypes.HRESULT
RoInitialize.argtypes = (wintypes.UINT,)

# void RoUninitialize()
RoUninitialize = combase.RoUninitialize
RoUninitialize.restype = None
RoUninitialize.argtypes = ()

# HRESULT WindowsCreateStringReference(PCWSTR, UINT32, HSTRING_HEADER*, HSTRING*)
WindowsCreateStringReference = combase.WindowsCreateStringReference
WindowsCreateStringReference.restype = wintypes.HRESULT
WindowsCreateStringReference.argtypes = (
    wintypes.LPCWSTR,
    wintypes.UINT,
    ctypes.POINTER(HSTRING_HEADER),
    ctypes.POINTER(HSTRING),
)

# HRESULT RoActivateInstance(HSTRING, IInspectable**)
RoActivateInstance = combase.RoActivateInstance
RoActivateInstance.restype = wintypes.HRESULT
RoActivateInstance.argtypes = (HSTRING, ctypes.POINTER(ctypes.c_void_p))

# HRESULT RoGetActivationFactory(HSTRING, REFIID, void**)
RoGetActivationFactory = combase.RoGetActivationFactory
RoGetActivationFactory.restype = wintypes.HRESULT
RoGetActivationFactory.argtypes = (
    HSTRING,
    ctypes.POINTER(GUID),
    ctypes.POINTER(ctypes.c_void_p),
)

# ============================================================
# COM VTable helper
# ============================================================
def com_method(obj, index: int, restype, argtypes):
    """
    Call a COM method by VTable index.
    
    Args:
        obj: COM interface pointer (as int or c_void_p)
        index: VTable index (0=QueryInterface, 1=AddRef, 2=Release, ...)
        restype: Return type of the method
        argtypes: Tuple of argument types
    
    Returns:
        A callable function for the COM method
    """
    if isinstance(obj, ctypes.c_void_p):
        ptr_value = obj.value
    elif isinstance(obj, int):
        ptr_value = obj
    else:
        ptr_value = obj
    
    if ptr_value is None or ptr_value == 0:
        raise RuntimeError(f"com_method: NULL pointer at index {index}")
    
    # Dereference the vtable pointer
    vtbl = ctypes.cast(ptr_value, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    fn_addr = vtbl[index]
    FN = ctypes.WINFUNCTYPE(restype, *argtypes)
    return FN(fn_addr)

def com_release(obj):
    """
    Call IUnknown::Release (VTable index 2)
    
    Args:
        obj: COM interface pointer to release
    """
    if obj:
        ptr = obj.value if isinstance(obj, ctypes.c_void_p) else obj
        if ptr:
            try:
                com_method(ptr, 2, wintypes.ULONG, (ctypes.c_void_p,))(ptr)
            except Exception:
                pass

def com_query_interface(obj, iid: GUID):
    """
    Call IUnknown::QueryInterface (VTable index 0)
    
    Args:
        obj: Source COM interface pointer
        iid: Target interface GUID
    
    Returns:
        New interface pointer
    """
    ptr = obj.value if isinstance(obj, ctypes.c_void_p) else obj
    result = ctypes.c_void_p()
    qi = com_method(ptr, 0, wintypes.HRESULT,
                   (ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p)))
    hr = qi(ptr, ctypes.byref(iid), ctypes.byref(result))
    if hr != S_OK:
        raise RuntimeError(f"QueryInterface failed: 0x{hr & 0xFFFFFFFF:08X}")
    return result

# ============================================================
# Helper: Create HSTRING from Python string
# ============================================================
def create_hstring(s: str):
    """
    Create an HSTRING reference from a Python string.
    
    IMPORTANT: WindowsCreateStringReference does NOT copy the string.
    It creates a reference to the original buffer. Therefore, we must
    keep the buffer alive as long as the HSTRING is in use.
    
    Args:
        s: Python string to convert
    
    Returns:
        Tuple of (buffer, header, hstring) - all must be kept alive!
    """
    # Create a persistent unicode buffer that won't be garbage collected
    buffer = ctypes.create_unicode_buffer(s)
    header = HSTRING_HEADER()
    hstring = HSTRING()
    
    hr = WindowsCreateStringReference(buffer, len(s), ctypes.byref(header), ctypes.byref(hstring))
    if hr != S_OK:
        raise RuntimeError(f"WindowsCreateStringReference failed: 0x{hr & 0xFFFFFFFF:08X}")
    
    # Return all three objects - caller must keep them alive
    return buffer, header, hstring

# ============================================================
# Create XML Document from string
# ============================================================
def create_xml_document_from_string(xml_string: str):
    """
    Create IXmlDocument from XML string.
    
    VTable layout for WinRT interfaces:
    - 0: QueryInterface (IUnknown)
    - 1: AddRef (IUnknown)
    - 2: Release (IUnknown)
    - 3: Iunknown3 (IInspectable)
    - 4: Iunknown4 (IInspectable)
    - 5: Iunknown5 (IInspectable)
    - 6+: Interface-specific methods
    
    Args:
        xml_string: XML content as string
    
    Returns:
        IXmlDocument interface pointer
    """
    # Create HSTRING for RuntimeClass name
    buf_class, hdr_class, hs_class = create_hstring(RuntimeClass_Windows_Data_Xml_Dom_XmlDocument)
    
    # RoActivateInstance to get IInspectable
    inspectable = ctypes.c_void_p()
    hr = RoActivateInstance(hs_class, ctypes.byref(inspectable))
    if hr != S_OK:
        raise RuntimeError(f"RoActivateInstance(XmlDocument) failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print(f"XmlDocument IInspectable: 0x{inspectable.value:016X}")
    
    # QueryInterface for IXmlDocument
    xml_doc = com_query_interface(inspectable, IID_IXmlDocument)
    debug_print(f"IXmlDocument: 0x{xml_doc.value:016X}")
    com_release(inspectable)
    
    # QueryInterface for IXmlDocumentIO
    xml_doc_io = com_query_interface(xml_doc, IID_IXmlDocumentIO)
    debug_print(f"IXmlDocumentIO: 0x{xml_doc_io.value:016X}")
    
    # Create HSTRING for XML content
    buf_xml, hdr_xml, hs_xml = create_hstring(xml_string)
    
    # IXmlDocumentIO::LoadXml (VTable index 6)
    # Index: IUnknown(0-2) + IInspectable(3-5) + LoadXml(6)
    load_xml = com_method(xml_doc_io.value, 6, wintypes.HRESULT, (ctypes.c_void_p, HSTRING))
    hr = load_xml(xml_doc_io.value, hs_xml)
    if hr != S_OK:
        raise RuntimeError(f"IXmlDocumentIO::LoadXml failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("XML loaded successfully")
    
    com_release(xml_doc_io)
    
    return xml_doc

# ============================================================
# Main
# ============================================================
def main():
    debug_print("=== Starting Toast Notification ===")
    debug_print(f"Python executable: {sys.executable}")
    if "windowsapps" in os.path.normcase(sys.executable):
        debug_print(
            "WARNING: Running under Microsoft Store Python alias (WindowsApps). "
            "Desktop toast routing with custom AppID may not work reliably."
        )

    # Helps desktop toast routing for non-packaged apps (python.exe host)
    hr = shell32.SetCurrentProcessExplicitAppUserModelID(APP_ID)
    debug_print(f"SetCurrentProcessExplicitAppUserModelID: 0x{hr & 0xFFFFFFFF:08X}")
    
    # Initialize WinRT
    hr = RoInitialize(RO_INIT_MULTITHREADED)
    if hr != S_OK and hr != S_FALSE:  # S_OK or S_FALSE (already initialized)
        raise RuntimeError(f"RoInitialize failed: 0x{hr & 0xFFFFFFFF:08X}")
    debug_print("WinRT initialized")
    
    try:
        # Create XML Document for toast content (same as C version)
        xml_string = (
            '<toast activationType="protocol" launch="imsprevn://0" duration="long">\r\n'
            '	<visual>\r\n'
            '		<binding template="ToastGeneric">\r\n'
            '			<text><![CDATA[Hello, WinRT World!]]></text>\r\n'
            '		</binding>\r\n'
            '	</visual>\r\n'
            '	<audio src="ms-winsoundevent:Notification.Mail" loop="false" />\r\n'
            '</toast>\r\n'
        )
        input_xml = create_xml_document_from_string(xml_string)
        
        # Get ToastNotificationManagerStatics factory
        buf_tnm, hdr_tnm, hs_tnm = create_hstring(
            RuntimeClass_Windows_UI_Notifications_ToastNotificationManager
        )
        
        toast_statics = ctypes.c_void_p()
        hr = RoGetActivationFactory(
            hs_tnm,
            ctypes.byref(IID_IToastNotificationManagerStatics),
            ctypes.byref(toast_statics)
        )
        if hr != S_OK:
            raise RuntimeError(
                f"RoGetActivationFactory(ToastNotificationManager) failed: 0x{hr & 0xFFFFFFFF:08X}"
            )
        debug_print(f"IToastNotificationManagerStatics: 0x{toast_statics.value:016X}")
        
        # IToastNotificationManagerStatics methods:
        # VTable: IUnknown(0-2) + IInspectable(3-5) + CreateToastNotifier(6) + CreateToastNotifierWithId(7) + ...
        
        # Create notifier with App ID
        notifier = ctypes.c_void_p()
        buf_appid, hdr_appid, hs_appid = create_hstring(APP_ID)
        debug_print(f"Using App ID: {APP_ID}")
        
        create_notifier_with_id = com_method(
            toast_statics.value, 7, wintypes.HRESULT,
            (ctypes.c_void_p, HSTRING, ctypes.POINTER(ctypes.c_void_p))
        )
        hr = create_notifier_with_id(toast_statics.value, hs_appid, ctypes.byref(notifier))
        
        if hr != S_OK:
            raise RuntimeError(f"CreateToastNotifierWithId failed: 0x{hr & 0xFFFFFFFF:08X}")
        
        debug_print(f"IToastNotifier: 0x{notifier.value:016X}")
        
        # Get ToastNotificationFactory
        buf_tn, hdr_tn, hs_tn = create_hstring(
            RuntimeClass_Windows_UI_Notifications_ToastNotification
        )
        
        notif_factory = ctypes.c_void_p()
        hr = RoGetActivationFactory(
            hs_tn,
            ctypes.byref(IID_IToastNotificationFactory),
            ctypes.byref(notif_factory)
        )
        if hr != S_OK:
            raise RuntimeError(
                f"RoGetActivationFactory(ToastNotification) failed: 0x{hr & 0xFFFFFFFF:08X}"
            )
        debug_print(f"IToastNotificationFactory: 0x{notif_factory.value:016X}")
        
        # IToastNotificationFactory::CreateToastNotification (VTable index 6)
        # Index: IUnknown(0-2) + IInspectable(3-5) + CreateToastNotification(6)
        toast = ctypes.c_void_p()
        create_toast = com_method(
            notif_factory.value, 6, wintypes.HRESULT,
            (ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p))
        )
        hr = create_toast(notif_factory.value, input_xml.value, ctypes.byref(toast))
        if hr != S_OK:
            raise RuntimeError(f"CreateToastNotification failed: 0x{hr & 0xFFFFFFFF:08X}")
        debug_print(f"IToastNotification: 0x{toast.value:016X}")
        
        # IToastNotifier::Show (VTable index 6)
        # Index: IUnknown(0-2) + IInspectable(3-5) + Show(6)
        show = com_method(
            notifier.value, 6, wintypes.HRESULT,
            (ctypes.c_void_p, ctypes.c_void_p)
        )
        hr = show(notifier.value, toast.value)
        if hr != S_OK:
            raise RuntimeError(f"IToastNotifier::Show failed: 0x{hr & 0xFFFFFFFF:08X}")
        debug_print("Toast notification shown!")
        
        # Keep the program running to see the notification
        # Toast may not appear if the program exits too quickly
        print("\nPress Enter to exit...")
        input()
        
        # Cleanup COM objects (release in reverse order of creation)
        com_release(toast)
        com_release(notif_factory)
        com_release(notifier)
        com_release(toast_statics)
        com_release(input_xml)
        
        debug_print("=== Toast Notification Complete ===")
        
    finally:
        RoUninitialize()
        debug_print("WinRT uninitialized")

if __name__ == "__main__":
    main()
