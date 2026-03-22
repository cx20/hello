# WinRT Toast Notification (Fiddle only, no external libraries)
#
# This sample demonstrates how to show a Windows Toast Notification
# using only Ruby's Fiddle without any external gems.
#
# VTable layout for WinRT interfaces:
#   0: QueryInterface  (IUnknown)
#   1: AddRef          (IUnknown)
#   2: Release         (IUnknown)
#   3: GetIids         (IInspectable)
#   4: GetRuntimeClassName (IInspectable)
#   5: GetTrustLevel   (IInspectable)
#   6+: Interface-specific methods

require 'fiddle'

# ============================================================
# Constants
# ============================================================
RO_INIT_MULTITHREADED = 1
S_OK   = 0
S_FALSE = 1

# Dummy App ID for desktop toast routing (same as C/Python version)
APP_ID = "0123456789ABCDEF"

SIZEOF_PTR = Fiddle::SIZEOF_VOIDP
PTR_PACK   = SIZEOF_PTR == 8 ? 'Q<' : 'V'
HSTRING_HEADER_SIZE = SIZEOF_PTR * 5  # Opaque header: 5 pointers

# WinRT Runtime Class names
RUNTIMECLASS_XML_DOCUMENT        = "Windows.Data.Xml.Dom.XmlDocument"
RUNTIMECLASS_TOAST_MANAGER       = "Windows.UI.Notifications.ToastNotificationManager"
RUNTIMECLASS_TOAST_NOTIFICATION  = "Windows.UI.Notifications.ToastNotification"

# Calling convention (STDCALL == default on x64, but explicit for clarity)
CALL_CONV = defined?(Fiddle::Function::STDCALL) ? Fiddle::Function::STDCALL : Fiddle::Function::DEFAULT

# ============================================================
# GUIDs (packed as 16-byte binary: DWORD + WORD + WORD + BYTE[8])
# ============================================================
def make_guid(d1, d2, d3, *d4)
  [d1, d2, d3, *d4].pack('VvvC8')
end

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
# DLL loading and function imports
# ============================================================
$combase  = Fiddle.dlopen('combase')
$shell32  = Fiddle.dlopen('shell32')
$kernel32 = Fiddle.dlopen('kernel32')

def winapi(dll, name, arg_types, ret_type)
  Fiddle::Function.new(dll[name], arg_types, ret_type, CALL_CONV)
end

# combase.dll - WinRT runtime functions
RoInitialize = winapi($combase, 'RoInitialize',
  [Fiddle::TYPE_INT], Fiddle::TYPE_LONG)

RoUninitialize = winapi($combase, 'RoUninitialize',
  [], Fiddle::TYPE_VOID)

WindowsCreateStringReference = winapi($combase, 'WindowsCreateStringReference',
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP],
  Fiddle::TYPE_LONG)

RoActivateInstance = winapi($combase, 'RoActivateInstance',
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)

RoGetActivationFactory = winapi($combase, 'RoGetActivationFactory',
  [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)

# shell32.dll - App ID registration
SetCurrentProcessExplicitAppUserModelID = winapi($shell32,
  'SetCurrentProcessExplicitAppUserModelID',
  [Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)

# kernel32.dll - Debug output
OutputDebugStringW = winapi($kernel32, 'OutputDebugStringW',
  [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOID)

# ============================================================
# GC guard: prevent garbage collection of allocated buffers
# WindowsCreateStringReference does NOT copy the string, so
# the original buffer must remain alive as long as the HSTRING
# is in use.
# ============================================================
$gc_guard = []

def alloc(size)
  ptr = Fiddle::Pointer.malloc(size)
  $gc_guard << ptr
  ptr
end

# ============================================================
# Wide string (UTF-16LE) helper
# ============================================================
def to_wstr_ptr(str)
  wstr = (str + "\0").encode('UTF-16LE')
  ptr = alloc(wstr.bytesize)
  ptr[0, wstr.bytesize] = wstr
  ptr
end

# ============================================================
# Debug output
# ============================================================
def debug_print(msg)
  wstr = ("[RbToast] #{msg}\n\0").encode('UTF-16LE')
  buf = Fiddle::Pointer.malloc(wstr.bytesize)
  buf[0, wstr.bytesize] = wstr
  OutputDebugStringW.call(buf)
  puts "[RbToast] #{msg}"
end

# ============================================================
# HSTRING helper
# ============================================================
def create_hstring(str)
  # Allocate a persistent UTF-16LE buffer (must outlive the HSTRING)
  wstr = (str + "\0").encode('UTF-16LE')
  buf = alloc(wstr.bytesize)
  buf[0, wstr.bytesize] = wstr

  header = alloc(HSTRING_HEADER_SIZE)
  hs_out = alloc(SIZEOF_PTR)

  hr = WindowsCreateStringReference.call(buf, str.length, header, hs_out)
  raise format("WindowsCreateStringReference failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK

  # Return the HSTRING handle value (integer)
  hs = hs_out[0, SIZEOF_PTR].unpack1(PTR_PACK)
  [buf, header, hs]
end

# ============================================================
# COM VTable helpers
# ============================================================

# Create a callable function from a COM object's VTable at the given index
def com_call(obj_addr, index, arg_types, ret_type = Fiddle::TYPE_LONG)
  vtbl = Fiddle::Pointer.new(obj_addr)[0, SIZEOF_PTR].unpack1(PTR_PACK)
  fn   = Fiddle::Pointer.new(vtbl + index * SIZEOF_PTR)[0, SIZEOF_PTR].unpack1(PTR_PACK)
  Fiddle::Function.new(Fiddle::Pointer.new(fn), arg_types, ret_type, CALL_CONV)
end

# IUnknown::Release (VTable index 2)
def com_release(obj_addr)
  return if obj_addr.nil? || obj_addr == 0
  com_call(obj_addr, 2, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG).call(obj_addr)
rescue
  # Ignore release errors during cleanup
end

# IUnknown::QueryInterface (VTable index 0)
def com_query_interface(obj_addr, iid_bytes)
  iid_buf = alloc(16)
  iid_buf[0, 16] = iid_bytes

  out = alloc(SIZEOF_PTR)
  hr = com_call(obj_addr, 0,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP]
  ).call(obj_addr, iid_buf, out)
  raise format("QueryInterface failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK

  out[0, SIZEOF_PTR].unpack1(PTR_PACK)
end

# ============================================================
# Create IXmlDocument from XML string
# ============================================================
def create_xml_document_from_string(xml_string)
  # RoActivateInstance to get IInspectable for XmlDocument
  _buf, _hdr, hs_class = create_hstring(RUNTIMECLASS_XML_DOCUMENT)

  inspectable_out = alloc(SIZEOF_PTR)
  hr = RoActivateInstance.call(hs_class, inspectable_out)
  raise format("RoActivateInstance(XmlDocument) failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK
  inspectable = inspectable_out[0, SIZEOF_PTR].unpack1(PTR_PACK)
  debug_print format("XmlDocument IInspectable: 0x%016X", inspectable)

  # QueryInterface for IXmlDocument
  xml_doc = com_query_interface(inspectable, IID_IXmlDocument)
  debug_print format("IXmlDocument: 0x%016X", xml_doc)
  com_release(inspectable)

  # QueryInterface for IXmlDocumentIO (needed for LoadXml)
  xml_doc_io = com_query_interface(xml_doc, IID_IXmlDocumentIO)
  debug_print format("IXmlDocumentIO: 0x%016X", xml_doc_io)

  # IXmlDocumentIO::LoadXml (VTable index 6)
  # Layout: IUnknown(0-2) + IInspectable(3-5) + LoadXml(6)
  _buf_xml, _hdr_xml, hs_xml = create_hstring(xml_string)
  hr = com_call(xml_doc_io, 6,
    [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP]
  ).call(xml_doc_io, hs_xml)
  raise format("IXmlDocumentIO::LoadXml failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK
  debug_print "XML loaded successfully"

  com_release(xml_doc_io)
  xml_doc
end

# ============================================================
# Main
# ============================================================
def main
  debug_print "=== Starting Toast Notification ==="
  debug_print "Ruby: #{RUBY_VERSION} (#{RUBY_PLATFORM})"

  # Set AppUserModelID for desktop toast routing (non-packaged apps)
  app_id_ptr = to_wstr_ptr(APP_ID)
  hr = SetCurrentProcessExplicitAppUserModelID.call(app_id_ptr)
  debug_print format("SetCurrentProcessExplicitAppUserModelID: 0x%08X", hr & 0xFFFFFFFF)

  # Initialize WinRT
  hr = RoInitialize.call(RO_INIT_MULTITHREADED)
  unless hr == S_OK || hr == S_FALSE
    raise format("RoInitialize failed: 0x%08X", hr & 0xFFFFFFFF)
  end
  debug_print "WinRT initialized"

  begin
    # Toast XML content (same structure as C/Python version)
    xml_string =
      "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n" \
      "\t<visual>\r\n" \
      "\t\t<binding template=\"ToastGeneric\">\r\n" \
      "\t\t\t<text><![CDATA[Hello, WinRT(Ruby) World!]]></text>\r\n" \
      "\t\t</binding>\r\n" \
      "\t</visual>\r\n" \
      "\t<audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n" \
      "</toast>\r\n"

    input_xml = create_xml_document_from_string(xml_string)

    # ---- ToastNotificationManager ----
    # Get IToastNotificationManagerStatics via activation factory
    _buf_tnm, _hdr_tnm, hs_tnm = create_hstring(RUNTIMECLASS_TOAST_MANAGER)
    iid_statics_buf = alloc(16)
    iid_statics_buf[0, 16] = IID_IToastNotificationManagerStatics

    statics_out = alloc(SIZEOF_PTR)
    hr = RoGetActivationFactory.call(hs_tnm, iid_statics_buf, statics_out)
    raise format("RoGetActivationFactory(ToastNotificationManager) failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK
    toast_statics = statics_out[0, SIZEOF_PTR].unpack1(PTR_PACK)
    debug_print format("IToastNotificationManagerStatics: 0x%016X", toast_statics)

    # IToastNotificationManagerStatics::CreateToastNotifierWithId (VTable index 7)
    # Layout: IUnknown(0-2) + IInspectable(3-5) + CreateToastNotifier(6) + CreateToastNotifierWithId(7)
    _buf_appid, _hdr_appid, hs_appid = create_hstring(APP_ID)
    notifier_out = alloc(SIZEOF_PTR)
    debug_print "Using App ID: #{APP_ID}"

    hr = com_call(toast_statics, 7,
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP]
    ).call(toast_statics, hs_appid, notifier_out)
    raise format("CreateToastNotifierWithId failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK
    notifier = notifier_out[0, SIZEOF_PTR].unpack1(PTR_PACK)
    debug_print format("IToastNotifier: 0x%016X", notifier)

    # ---- ToastNotificationFactory ----
    # Get IToastNotificationFactory via activation factory
    _buf_tn, _hdr_tn, hs_tn = create_hstring(RUNTIMECLASS_TOAST_NOTIFICATION)
    iid_factory_buf = alloc(16)
    iid_factory_buf[0, 16] = IID_IToastNotificationFactory

    factory_out = alloc(SIZEOF_PTR)
    hr = RoGetActivationFactory.call(hs_tn, iid_factory_buf, factory_out)
    raise format("RoGetActivationFactory(ToastNotification) failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK
    notif_factory = factory_out[0, SIZEOF_PTR].unpack1(PTR_PACK)
    debug_print format("IToastNotificationFactory: 0x%016X", notif_factory)

    # IToastNotificationFactory::CreateToastNotification (VTable index 6)
    # Layout: IUnknown(0-2) + IInspectable(3-5) + CreateToastNotification(6)
    toast_out = alloc(SIZEOF_PTR)
    hr = com_call(notif_factory, 6,
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP]
    ).call(notif_factory, input_xml, toast_out)
    raise format("CreateToastNotification failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK
    toast = toast_out[0, SIZEOF_PTR].unpack1(PTR_PACK)
    debug_print format("IToastNotification: 0x%016X", toast)

    # ---- Show the toast ----
    # IToastNotifier::Show (VTable index 6)
    # Layout: IUnknown(0-2) + IInspectable(3-5) + Show(6)
    hr = com_call(notifier, 6,
      [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP]
    ).call(notifier, toast)
    raise format("IToastNotifier::Show failed: 0x%08X", hr & 0xFFFFFFFF) unless hr == S_OK
    debug_print "Toast notification shown!"

    # Keep the program running so the notification remains visible
    puts "\nPress Enter to exit..."
    gets

    # Cleanup COM objects (release in reverse order of creation)
    com_release(toast)
    com_release(notif_factory)
    com_release(notifier)
    com_release(toast_statics)
    com_release(input_xml)

    debug_print "=== Toast Notification Complete ==="
  ensure
    RoUninitialize.call
    debug_print "WinRT uninitialized"
  end
end

main
