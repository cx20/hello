program hello_toast;

(*
 * hello_toast.pas
 *
 * Display a Windows Toast notification using WinRT COM vtable calls.
 * Uses Free Pascal's COM interface support for automatic vtable dispatch
 * and reference counting, while loading combase.dll functions dynamically.
 *
 * Build (Free Pascal x86_64):
 *   fpc -Twin64 hello_toast.pas
 *
 * Build (Free Pascal i386):
 *   fpc -Twin32 hello_toast.pas
 *
 * Requirements:
 *   - Free Pascal 3.2.0 or later
 *   - Windows 10 or later
 *)

{$ifdef fpc}
  {$mode delphi}
{$endif}
{$apptype gui}

uses
  Windows;

(* ============================================================
 * Constants
 * ============================================================ *)
const
  RO_INIT_MULTITHREADED = 1;
  APP_ID = '0123456789ABCDEF';

(* ============================================================
 * HSTRING types
 *
 * HSTRING is an opaque handle to a WinRT immutable string.
 * HSTRING_HEADER is the backing storage for a stack-allocated
 * HSTRING reference created by WindowsCreateStringReference.
 * Size: 24 bytes on x64, 20 bytes on x86.
 * ============================================================ *)
type
  HSTRING = NativeUInt;

  HSTRING_HEADER = record
    {$ifdef CPU64}
    Reserved: array[0..23] of Byte;
    {$else}
    Reserved: array[0..19] of Byte;
    {$endif}
  end;

(* ============================================================
 * WinRT interface declarations
 *
 * Free Pascal COM interfaces provide:
 *   - Automatic vtable dispatch (the compiler generates the
 *     correct indirect call through the vtable pointer)
 *   - Automatic reference counting (_AddRef on assignment,
 *     _Release when the variable goes out of scope or is set
 *     to nil)
 *   - Built-in QueryInterface via interface type GUIDs
 *
 * WinRT interfaces inherit from IInspectable which adds 3 methods
 * (slots 3-5) on top of IUnknown's 3 (slots 0-2).
 * Interface-specific methods start at vtable slot 6.
 *
 * Method declarations must exactly match the IDL ordering so that
 * the compiler calculates the correct vtable slot offset.
 * ============================================================ *)
type
  (* IInspectable — base interface for all WinRT runtime classes *)
  IInspectable = interface(IUnknown)
    ['{AF86E2E0-B12D-4C6A-9C5A-D7AA65101E90}']
    function GetIids(out iidCount: Cardinal; out iids: PGUID): HRESULT; stdcall;
    function GetRuntimeClassName(out name: HSTRING): HRESULT; stdcall;
    function GetTrustLevel(out level: Integer): HRESULT; stdcall;
  end;

  (* Windows.Data.Xml.Dom.IXmlDocument
   * We only need the type for QueryInterface and to pass it
   * to CreateToastNotification — no additional methods required. *)
  IXmlDocument = interface(IInspectable)
    ['{F7F3A506-1E87-42D6-BCFB-B8C809FA5494}']
  end;

  (* Windows.Data.Xml.Dom.IXmlDocumentIO
   *   slot 6: LoadXml(HSTRING xml) *)
  IXmlDocumentIO = interface(IInspectable)
    ['{6CD0E74E-EE65-4489-9EBF-CA43E87BA637}']
    function LoadXml(xml: HSTRING): HRESULT; stdcall;
  end;

  (* Windows.UI.Notifications.IToastNotification
   * Used as an opaque handle — no methods called directly. *)
  IToastNotification = interface(IInspectable)
    ['{997E2675-059E-4E60-8B06-1760917C8B80}']
  end;

  (* Windows.UI.Notifications.IToastNotifier
   *   slot 6: Show(IToastNotification notification) *)
  IToastNotifier = interface(IInspectable)
    ['{75927B93-03F3-41EC-91D3-6E5BAC1B38E7}']
    function Show(const notification: IToastNotification): HRESULT; stdcall;
  end;

  (* Windows.UI.Notifications.IToastNotificationManagerStatics
   *   slot 6: CreateToastNotifier() -> IToastNotifier
   *   slot 7: CreateToastNotifierWithId(HSTRING, out IToastNotifier) *)
  IToastNotificationManagerStatics = interface(IInspectable)
    ['{50AC103F-D235-4598-BBEF-98FE4D1A3AD4}']
    function CreateToastNotifier(out notifier: IToastNotifier): HRESULT; stdcall;
    function CreateToastNotifierWithId(appId: HSTRING; out notifier: IToastNotifier): HRESULT; stdcall;
  end;

  (* Windows.UI.Notifications.IToastNotificationFactory
   *   slot 6: CreateToastNotification(IXmlDocument, out IToastNotification) *)
  IToastNotificationFactory = interface(IInspectable)
    ['{04124B20-82C6-4229-B109-FD9ED4662B53}']
    function CreateToastNotification(const content: IXmlDocument; out notification: IToastNotification): HRESULT; stdcall;
  end;

(* ============================================================
 * combase.dll function types
 *
 * These WinRT bootstrap functions are loaded dynamically since
 * they are not available in standard Free Pascal import units.
 * ============================================================ *)
type
  TRoInitialize = function(initType: Cardinal): HRESULT; stdcall;
  TRoUninitialize = procedure; stdcall;
  TRoActivateInstance = function(
    classId: HSTRING;
    out instance: IInspectable
  ): HRESULT; stdcall;
  TRoGetActivationFactory = function(
    classId: HSTRING;
    const riid: TGUID;
    out factory
  ): HRESULT; stdcall;
  TWindowsCreateStringReference = function(
    sourceString: PWideChar;
    length: Cardinal;
    out hstringHeader: HSTRING_HEADER;
    out str: HSTRING
  ): HRESULT; stdcall;

(* ============================================================
 * Global function pointers (loaded from combase.dll)
 * ============================================================ *)
var
  hCombase: THandle;
  RoInitialize: TRoInitialize;
  RoUninitialize: TRoUninitialize;
  RoActivateInstance: TRoActivateInstance;
  RoGetActivationFactory: TRoGetActivationFactory;
  WindowsCreateStringReference: TWindowsCreateStringReference;

(* ============================================================
 * GUIDs used with RoGetActivationFactory
 *
 * These must match the interface GUIDs declared above.
 * We define them as separate TGUID constants because
 * RoGetActivationFactory is a plain function pointer (not a
 * COM method), so the compiler cannot automatically extract
 * the GUID from an interface type name.
 * ============================================================ *)
const
  IID_IToastNotificationManagerStatics: TGUID =
    '{50AC103F-D235-4598-BBEF-98FE4D1A3AD4}';
  IID_IToastNotificationFactory: TGUID =
    '{04124B20-82C6-4229-B109-FD9ED4662B53}';

(* ============================================================
 * Load combase.dll and resolve function pointers
 * ============================================================ *)
function LoadCombaseFunctions: Boolean;
begin
  hCombase := LoadLibrary('combase.dll');
  if hCombase = 0 then
    Exit(False);

  RoInitialize := TRoInitialize(GetProcAddress(hCombase, 'RoInitialize'));
  RoUninitialize := TRoUninitialize(GetProcAddress(hCombase, 'RoUninitialize'));
  RoActivateInstance := TRoActivateInstance(GetProcAddress(hCombase, 'RoActivateInstance'));
  RoGetActivationFactory := TRoGetActivationFactory(GetProcAddress(hCombase, 'RoGetActivationFactory'));
  WindowsCreateStringReference := TWindowsCreateStringReference(GetProcAddress(hCombase, 'WindowsCreateStringReference'));

  Result := Assigned(RoInitialize) and
            Assigned(RoUninitialize) and
            Assigned(RoActivateInstance) and
            Assigned(RoGetActivationFactory) and
            Assigned(WindowsCreateStringReference);
end;

(* ============================================================
 * Create a stack-based HSTRING reference from a WideString.
 *
 * The HSTRING is only valid while both the WideString and the
 * HSTRING_HEADER remain in scope. WindowsCreateStringReference
 * does not copy the string data — it creates a lightweight
 * reference to the caller's buffer.
 * ============================================================ *)
function CreateHStringRef(const ws: WideString; out header: HSTRING_HEADER): HSTRING;
begin
  Result := 0;
  if Length(ws) > 0 then
    WindowsCreateStringReference(PWideChar(ws), Length(ws), header, Result);
end;

(* ============================================================
 * Create an IXmlDocument from an XML string.
 *
 * Flow:
 *   1. RoActivateInstance("Windows.Data.Xml.Dom.XmlDocument")
 *      -> IInspectable
 *   2. QueryInterface for IXmlDocument (to return to caller)
 *   3. QueryInterface for IXmlDocumentIO (to call LoadXml)
 *   4. IXmlDocumentIO::LoadXml(xmlString)
 * ============================================================ *)
function CreateXmlDocumentFromString(
  const xmlString: WideString;
  out doc: IXmlDocument
): HRESULT;
var
  headerClass, headerXml: HSTRING_HEADER;
  hsClass, hsXml: HSTRING;
  inspectable: IInspectable;
  docIO: IXmlDocumentIO;
begin
  (* Activate the XmlDocument runtime class *)
  hsClass := CreateHStringRef('Windows.Data.Xml.Dom.XmlDocument', headerClass);

  Result := RoActivateInstance(hsClass, inspectable);
  if Failed(Result) then Exit;

  (* QueryInterface for IXmlDocument *)
  Result := inspectable.QueryInterface(IXmlDocument, doc);
  if Failed(Result) then Exit;

  (* QueryInterface for IXmlDocumentIO to access LoadXml *)
  Result := doc.QueryInterface(IXmlDocumentIO, docIO);
  if Failed(Result) then Exit;

  (* Parse the XML string *)
  hsXml := CreateHStringRef(xmlString, headerXml);
  Result := docIO.LoadXml(hsXml);

  (* docIO and inspectable are released automatically when they
   * go out of scope, thanks to Free Pascal's COM interface
   * reference counting. *)
end;

(* ============================================================
 * Main program
 * ============================================================ *)
var
  hr: HRESULT;
  headerAppId: HSTRING_HEADER;
  headerToastMgr: HSTRING_HEADER;
  headerToastNotif: HSTRING_HEADER;
  hsAppId: HSTRING;
  hsToastMgr: HSTRING;
  hsToastNotif: HSTRING;
  inputXml: IXmlDocument;
  toastStatics: IToastNotificationManagerStatics;
  notifier: IToastNotifier;
  notifFactory: IToastNotificationFactory;
  toast: IToastNotification;
begin
  (* Load combase.dll function pointers *)
  if not LoadCombaseFunctions then
    Exit;

  (* Initialize the WinRT runtime *)
  hr := RoInitialize(RO_INIT_MULTITHREADED);
  if Failed(hr) and (hr <> 1) then  (* 1 = S_FALSE: already initialized *)
    Exit;

  (* Create App ID HSTRING (dummy value — for real apps, use an AUMID
   * registered in the Start menu via a shortcut with AppUserModelID) *)
  hsAppId := CreateHStringRef(APP_ID, headerAppId);

  (* Build toast XML content and parse it into an XmlDocument *)
  hr := CreateXmlDocumentFromString(
    '<toast activationType="protocol" launch="imsprevn://0" duration="long">'#13#10 +
    '  <visual>'#13#10 +
    '    <binding template="ToastGeneric">'#13#10 +
    '      <text><![CDATA[Hello, WinRT(Pascal) World!]]></text>'#13#10 +
    '    </binding>'#13#10 +
    '  </visual>'#13#10 +
    '  <audio src="ms-winsoundevent:Notification.Mail" loop="false" />'#13#10 +
    '</toast>'#13#10,
    inputXml
  );
  if Failed(hr) then
  begin
    RoUninitialize;
    Exit;
  end;

  (* Obtain IToastNotificationManagerStatics via RoGetActivationFactory *)
  hsToastMgr := CreateHStringRef(
    'Windows.UI.Notifications.ToastNotificationManager', headerToastMgr);

  hr := RoGetActivationFactory(
    hsToastMgr,
    IID_IToastNotificationManagerStatics,
    toastStatics
  );
  if Failed(hr) then
  begin
    inputXml := nil;
    RoUninitialize;
    Exit;
  end;

  (* Create a ToastNotifier bound to our App ID *)
  hr := toastStatics.CreateToastNotifierWithId(hsAppId, notifier);
  if Failed(hr) then
  begin
    toastStatics := nil;
    inputXml := nil;
    RoUninitialize;
    Exit;
  end;

  (* Obtain IToastNotificationFactory via RoGetActivationFactory *)
  hsToastNotif := CreateHStringRef(
    'Windows.UI.Notifications.ToastNotification', headerToastNotif);

  hr := RoGetActivationFactory(
    hsToastNotif,
    IID_IToastNotificationFactory,
    notifFactory
  );
  if Failed(hr) then
  begin
    notifier := nil;
    toastStatics := nil;
    inputXml := nil;
    RoUninitialize;
    Exit;
  end;

  (* Create the ToastNotification object from our XML *)
  hr := notifFactory.CreateToastNotification(inputXml, toast);
  if Failed(hr) then
  begin
    notifFactory := nil;
    notifier := nil;
    toastStatics := nil;
    inputXml := nil;
    RoUninitialize;
    Exit;
  end;

  (* Show the toast notification *)
  notifier.Show(toast);

  (* Brief sleep to allow the notification to be dispatched *)
  Sleep(1);

  (* Release all COM interfaces in reverse order BEFORE calling
   * RoUninitialize. This is critical — releasing WinRT objects
   * after RoUninitialize would access freed runtime state.
   *
   * Setting interface variables to nil triggers _Release via
   * Free Pascal's automatic reference counting. *)
  toast := nil;
  notifFactory := nil;
  notifier := nil;
  toastStatics := nil;
  inputXml := nil;

  RoUninitialize;

  if hCombase <> 0 then
    FreeLibrary(hCombase);
end.
