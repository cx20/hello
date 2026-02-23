// WinRT Toast Notification Sample in D Language
// Build: dmd hello.d user32.lib
// Debug output via OutputDebugStringA (use Sysinternals DebugView to monitor)
//
// Key changes from previous version:
// - Uses RO_INIT_SINGLETHREADED (ASTA) instead of MTA
// - Uses a proper message pump loop instead of MessageBox
// - Verifies HSTRING_HEADER size at startup

import core.sys.windows.winbase;
import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.com;
import core.stdc.stdio : snprintf;

pragma(lib, "ole32");

// --- HSTRING types ---
alias HSTRING = void*;

struct HSTRING_HEADER
{
    union
    {
        void* Reserved1;
        byte[24] reserved;
    }
}

// --- Function pointer types for combase.dll ---
extern (Windows) nothrow @nogc
{
    alias pWindowsCreateStringReference = HRESULT function(
        const(wchar)* sourceString,
        uint length,
        HSTRING_HEADER* hstringHeader,
        HSTRING* string_
    );

    alias pRoInitialize = HRESULT function(uint initType);
    alias pRoUninitialize = void function();
    alias pRoActivateInstance = HRESULT function(HSTRING activatableClassId, void** instance);
    alias pRoGetActivationFactory = HRESULT function(HSTRING activatableClassId, const(GUID)* iid, void** factory);
}

__gshared pWindowsCreateStringReference WindowsCreateStringReference;
__gshared pRoInitialize RoInitialize;
__gshared pRoUninitialize RoUninitialize;
__gshared pRoActivateInstance RoActivateInstance;
__gshared pRoGetActivationFactory RoGetActivationFactory;

bool loadCombaseFunctions()
{
    HMODULE hCombase = LoadLibraryA("combase.dll");
    if (hCombase is null) return false;

    WindowsCreateStringReference = cast(pWindowsCreateStringReference)
        GetProcAddress(hCombase, "WindowsCreateStringReference");
    RoInitialize = cast(pRoInitialize)
        GetProcAddress(hCombase, "RoInitialize");
    RoUninitialize = cast(pRoUninitialize)
        GetProcAddress(hCombase, "RoUninitialize");
    RoActivateInstance = cast(pRoActivateInstance)
        GetProcAddress(hCombase, "RoActivateInstance");
    RoGetActivationFactory = cast(pRoGetActivationFactory)
        GetProcAddress(hCombase, "RoGetActivationFactory");

    return (WindowsCreateStringReference !is null)
        && (RoInitialize !is null)
        && (RoUninitialize !is null)
        && (RoActivateInstance !is null)
        && (RoGetActivationFactory !is null);
}

enum RO_INIT_SINGLETHREADED = 0;  // ASTA (Application STA)
enum RO_INIT_MULTITHREADED = 1;   // MTA

// --- Debug output helpers ---
void debugLog(const(char)* msg)
{
    OutputDebugStringA(msg);
}

void debugLogHR(const(char)* funcName, HRESULT hr)
{
    char[256] buf;
    snprintf(buf.ptr, buf.length, "[DToast] %s: hr=0x%08X %s\n",
        funcName, cast(uint)hr, hr == S_OK ? "OK".ptr : "FAILED".ptr);
    OutputDebugStringA(buf.ptr);
}

void debugLogPtr(const(char)* label, void* ptr)
{
    char[256] buf;
    snprintf(buf.ptr, buf.length, "[DToast] %s: ptr=%p %s\n",
        label, ptr, ptr !is null ? "OK".ptr : "NULL".ptr);
    OutputDebugStringA(buf.ptr);
}

void debugLogInt(const(char)* label, int val)
{
    char[256] buf;
    snprintf(buf.ptr, buf.length, "[DToast] %s: %d\n", label, val);
    OutputDebugStringA(buf.ptr);
}

void dumpVtable(const(char)* name, void* obj, int numSlots)
{
    if (obj is null) return;
    void** vtbl = *cast(void***)obj;
    char[256] buf;
    snprintf(buf.ptr, buf.length, "[DToast] --- vtable dump for %s (vtbl=%p) ---\n", name, cast(void*)vtbl);
    OutputDebugStringA(buf.ptr);
    for (int i = 0; i < numSlots; i++)
    {
        snprintf(buf.ptr, buf.length, "[DToast]   slot[%d] = %p\n", i, vtbl[i]);
        OutputDebugStringA(buf.ptr);
    }
}

// --- GUID definitions ---
immutable GUID UIID_IToastNotificationManagerStatics =
    GUID(0x50ac103f, 0xd235, 0x4598, [0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4]);
immutable GUID UIID_IToastNotificationFactory =
    GUID(0x04124b20, 0x82c6, 0x4229, [0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53]);
immutable GUID UIID_IXmlDocument =
    GUID(0xf7f3a506, 0x1e87, 0x42d6, [0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94]);
immutable GUID UIID_IXmlDocumentIO =
    GUID(0x6cd0e74e, 0xee65, 0x4489, [0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37]);

// --- Raw vtable access helpers ---
void** getVtbl(void* obj)
{
    return *cast(void***)obj;
}

void comRelease(void* obj)
{
    if (obj is null) return;
    alias Fn = extern (Windows) uint function(void*);
    (cast(Fn)(getVtbl(obj)[2]))(obj);
}

HRESULT comQueryInterface(void* obj, const(GUID)* iid, void** result)
{
    alias Fn = extern (Windows) HRESULT function(void*, const(GUID)*, void**);
    return (cast(Fn)(getVtbl(obj)[0]))(obj, iid, result);
}

// --- Interface method wrappers (slot numbers from SDK headers) ---

// IXmlDocumentIO: slot 6 = LoadXml
HRESULT xmlDocIO_LoadXml(void* docIO, HSTRING xml)
{
    alias Fn = extern (Windows) HRESULT function(void*, HSTRING);
    return (cast(Fn)(getVtbl(docIO)[6]))(docIO, xml);
}

// IToastNotificationManagerStatics:
//   slot 6 = GetTemplateContent
//   slot 7 = CreateToastNotifierWithId   (*** see note below ***)
//   slot 8 = CreateToastNotifier (parameterless)
//
// NOTE: The slot order can vary by SDK version.
// We try slot 7 first; if it produces a notifier that doesn't work,
// we also provide slot 8 as fallback.

HRESULT toastMgr_CreateToastNotifierWithId_Slot7(void* mgr, HSTRING appId, void** notifier)
{
    alias Fn = extern (Windows) HRESULT function(void*, HSTRING, void**);
    return (cast(Fn)(getVtbl(mgr)[7]))(mgr, appId, notifier);
}

// IToastNotificationFactory: slot 6 = CreateToastNotification
HRESULT toastFactory_CreateToastNotification(void* factory, void* xmlDoc, void** toast)
{
    alias Fn = extern (Windows) HRESULT function(void*, void*, void**);
    return (cast(Fn)(getVtbl(factory)[6]))(factory, xmlDoc, toast);
}

// IToastNotifier:
//   slot 6 = Show
//   slot 7 = Hide
//   slot 8 = get_Setting
HRESULT toastNotifier_Show(void* notifier, void* toast)
{
    alias Fn = extern (Windows) HRESULT function(void*, void*);
    return (cast(Fn)(getVtbl(notifier)[6]))(notifier, toast);
}

HRESULT toastNotifier_GetSetting(void* notifier, int* setting)
{
    alias Fn = extern (Windows) HRESULT function(void*, int*);
    return (cast(Fn)(getVtbl(notifier)[8]))(notifier, setting);
}

// --- Runtime class names (static immutable for stable addresses) ---
static immutable wchar[] RuntimeClass_XmlDocument =
    "Windows.Data.Xml.Dom.XmlDocument\0"w;
static immutable wchar[] RuntimeClass_ToastNotificationManager =
    "Windows.UI.Notifications.ToastNotificationManager\0"w;
static immutable wchar[] RuntimeClass_ToastNotification =
    "Windows.UI.Notifications.ToastNotification\0"w;
static immutable wchar[] APP_ID =
    "0123456789ABCDEF\0"w;
static immutable wchar[] toastXml =
    "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n"w ~
    "  <visual>\r\n"w ~
    "    <binding template=\"ToastGeneric\">\r\n"w ~
    "      <text><![CDATA[Hello, WinRT (D) World!]]></text>\r\n"w ~
    "    </binding>\r\n"w ~
    "  </visual>\r\n"w ~
    "  <audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n"w ~
    "</toast>\r\n\0"w;

// --- Helper: create HSTRING reference ---
// length must NOT include the null terminator
HRESULT createStringRef(const(wchar)* ptr, uint length, ref HSTRING_HEADER header, ref HSTRING hstr)
{
    return WindowsCreateStringReference(ptr, length, &header, &hstr);
}

// --- Create XmlDocument from XML string ---
HRESULT createXmlDocumentFromString(const(wchar)* xmlPtr, uint xmlLen, void** doc)
{
    HRESULT hr;
    debugLog("[DToast] --- createXmlDocumentFromString: begin ---\n");

    HSTRING_HEADER hdrClass;
    HSTRING hsClass;
    // -1 to exclude null terminator
    hr = createStringRef(RuntimeClass_XmlDocument.ptr,
        cast(uint)(RuntimeClass_XmlDocument.length - 1), hdrClass, hsClass);
    debugLogHR("  CreateStringRef(XmlDocument)", hr);
    if (hr != S_OK) return hr;

    void* pInspectable;
    hr = RoActivateInstance(hsClass, &pInspectable);
    debugLogHR("  RoActivateInstance(XmlDocument)", hr);
    debugLogPtr("  pInspectable", pInspectable);
    if (hr != S_OK) return hr;

    hr = comQueryInterface(pInspectable, &UIID_IXmlDocument, doc);
    debugLogHR("  QueryInterface(IXmlDocument)", hr);
    comRelease(pInspectable);
    if (hr != S_OK) return hr;

    void* docIO;
    hr = comQueryInterface(*doc, &UIID_IXmlDocumentIO, &docIO);
    debugLogHR("  QueryInterface(IXmlDocumentIO)", hr);
    if (hr != S_OK) return hr;

    HSTRING_HEADER hdrXml;
    HSTRING hsXml;
    hr = createStringRef(xmlPtr, xmlLen, hdrXml, hsXml);
    debugLogHR("  CreateStringRef(xmlString)", hr);
    if (hr != S_OK) { comRelease(docIO); return hr; }

    hr = xmlDocIO_LoadXml(docIO, hsXml);
    debugLogHR("  LoadXml (slot 6)", hr);
    comRelease(docIO);

    debugLog("[DToast] --- createXmlDocumentFromString: end ---\n");
    return hr;
}

// --- Message pump helper ---
void pumpMessages(uint durationMs)
{
    DWORD startTime = GetTickCount();
    MSG msg;
    while (GetTickCount() - startTime < durationMs)
    {
        while (PeekMessageA(&msg, null, 0, 0, 1/*PM_REMOVE*/))
        {
            TranslateMessage(&msg);
            DispatchMessageA(&msg);
            if (msg.message == 0x0012/*WM_QUIT*/) return;
        }
        Sleep(50);
    }
}

// --- Entry point ---
extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd)
{
    HRESULT hr;

    debugLog("[DToast] ===== Start =====\n");

    // Verify struct sizes
    {
        char[256] buf;
        snprintf(buf.ptr, buf.length,
            "[DToast] sizeof: HSTRING_HEADER=%d, void*=%d, GUID=%d\n",
            cast(int)HSTRING_HEADER.sizeof,
            cast(int)(void*).sizeof,
            cast(int)GUID.sizeof);
        OutputDebugStringA(buf.ptr);

        // HSTRING_HEADER must be 24 bytes on x64
        if (HSTRING_HEADER.sizeof != 24)
        {
            debugLog("[DToast] FATAL: HSTRING_HEADER size mismatch!\n");
            return 1;
        }
    }

    if (!loadCombaseFunctions())
    {
        debugLog("[DToast] FATAL: Failed to load combase.dll functions\n");
        return 1;
    }
    debugLog("[DToast] loadCombaseFunctions: OK\n");

    // Try ASTA (STA) first - toast notifications may require an STA thread
    hr = RoInitialize(RO_INIT_SINGLETHREADED);
    debugLogHR("RoInitialize(ASTA/STA)", hr);
    if (hr != S_OK && hr != 1) // S_OK or S_FALSE (already initialized)
    {
        // Fallback to MTA
        hr = RoInitialize(RO_INIT_MULTITHREADED);
        debugLogHR("RoInitialize(MTA) fallback", hr);
    }

    // App ID
    HSTRING_HEADER hdrAppId;
    HSTRING hsAppId;
    hr = createStringRef(APP_ID.ptr, cast(uint)(APP_ID.length - 1), hdrAppId, hsAppId);
    debugLogHR("CreateStringRef(APP_ID)", hr);

    // XML document
    void* inputXml;
    hr = createXmlDocumentFromString(toastXml.ptr, cast(uint)(toastXml.length - 1), &inputXml);
    debugLogHR("createXmlDocumentFromString", hr);
    debugLogPtr("inputXml", inputXml);
    if (hr != S_OK || inputXml is null)
    {
        debugLog("[DToast] FATAL: Failed to create XML document\n");
        RoUninitialize();
        return 1;
    }

    // ToastNotificationManagerStatics
    HSTRING_HEADER hdrManager;
    HSTRING hsManager;
    hr = createStringRef(RuntimeClass_ToastNotificationManager.ptr,
        cast(uint)(RuntimeClass_ToastNotificationManager.length - 1), hdrManager, hsManager);

    void* toastStatics;
    hr = RoGetActivationFactory(hsManager, &UIID_IToastNotificationManagerStatics, &toastStatics);
    debugLogHR("RoGetActivationFactory(ToastNotificationManagerStatics)", hr);
    if (hr != S_OK || toastStatics is null)
    {
        debugLog("[DToast] FATAL: Failed to get ToastNotificationManagerStatics\n");
        comRelease(inputXml);
        RoUninitialize();
        return 1;
    }

    dumpVtable("IToastNotificationManagerStatics", toastStatics, 9);

    // Create notifier
    void* notifier;
    hr = toastMgr_CreateToastNotifierWithId_Slot7(toastStatics, hsAppId, &notifier);
    debugLogHR("CreateToastNotifierWithId (slot 7)", hr);
    debugLogPtr("notifier", notifier);
    if (hr != S_OK || notifier is null)
    {
        debugLog("[DToast] FATAL: Failed to create notifier\n");
        comRelease(toastStatics);
        comRelease(inputXml);
        RoUninitialize();
        return 1;
    }

    // Check notification setting
    {
        int setting = -1;
        hr = toastNotifier_GetSetting(notifier, &setting);
        debugLogHR("get_Setting (slot 8)", hr);
        debugLogInt("NotificationSetting", setting);
    }

    // ToastNotificationFactory
    HSTRING_HEADER hdrNotif;
    HSTRING hsNotif;
    hr = createStringRef(RuntimeClass_ToastNotification.ptr,
        cast(uint)(RuntimeClass_ToastNotification.length - 1), hdrNotif, hsNotif);

    void* notifFactory;
    hr = RoGetActivationFactory(hsNotif, &UIID_IToastNotificationFactory, &notifFactory);
    debugLogHR("RoGetActivationFactory(ToastNotificationFactory)", hr);
    if (hr != S_OK || notifFactory is null)
    {
        debugLog("[DToast] FATAL: Failed to get ToastNotificationFactory\n");
        comRelease(notifier);
        comRelease(toastStatics);
        comRelease(inputXml);
        RoUninitialize();
        return 1;
    }

    // Create toast
    void* toast;
    hr = toastFactory_CreateToastNotification(notifFactory, inputXml, &toast);
    debugLogHR("CreateToastNotification (slot 6)", hr);
    debugLogPtr("toast", toast);
    if (hr != S_OK || toast is null)
    {
        debugLog("[DToast] FATAL: Failed to create toast notification\n");
        comRelease(notifFactory);
        comRelease(notifier);
        comRelease(toastStatics);
        comRelease(inputXml);
        RoUninitialize();
        return 1;
    }

    // Show toast
    hr = toastNotifier_Show(notifier, toast);
    debugLogHR("Show (slot 6)", hr);

    // Pump messages for 5 seconds to allow async notification delivery
    debugLog("[DToast] Pumping messages for 5 seconds...\n");
    pumpMessages(5000);

    debugLog("[DToast] Message pump done.\n");

    // Release
    debugLog("[DToast] Releasing COM objects...\n");
    comRelease(toast);
    comRelease(notifFactory);
    comRelease(notifier);
    comRelease(toastStatics);
    comRelease(inputXml);

    RoUninitialize();
    debugLog("[DToast] ===== End =====\n");

    return 0;
}