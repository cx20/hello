@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

/**
 * WinRT Toast Notification (pure Kotlin/Native, no external libraries)
 *
 * Build:
 *   kotlinc-native hello.kt -o hello
 *
 * Run:
 *   hello.exe
 *
 * Approach:
 *   - Dynamically load WinRT functions from combase.dll via GetProcAddress
 *   - Call COM methods by VTable index (raw pointer arithmetic)
 *   - GUID is manually laid out as 16 bytes (platform.windows.GUID is unavailable)
 *
 * VTable layout for WinRT interfaces:
 *   [0] QueryInterface     (IUnknown)
 *   [1] AddRef             (IUnknown)
 *   [2] Release            (IUnknown)
 *   [3] GetIids            (IInspectable)
 *   [4] GetRuntimeClassName (IInspectable)
 *   [5] GetTrustLevel      (IInspectable)
 *   [6+] Interface-specific methods
 *
 * forked from https://stackoverflow.com/questions/65387849/consume-windows-runtime-apis-from-pure-c
 */

import kotlinx.cinterop.*
import platform.windows.*

// ============================================================
// Constants
// ============================================================
private const val RO_INIT_MULTITHREADED = 1u
private const val S_OK = 0
private const val S_FALSE = 1
private const val GUID_SIZE = 16
private const val HSTRING_HEADER_SIZE = 40 // 5 * sizeof(void*) on x64
private const val APP_ID = "0123456789ABCDEF"

// Runtime Class Names
private const val RC_XmlDocument =
    "Windows.Data.Xml.Dom.XmlDocument"
private const val RC_ToastNotificationManager =
    "Windows.UI.Notifications.ToastNotificationManager"
private const val RC_ToastNotification =
    "Windows.UI.Notifications.ToastNotification"

// ============================================================
// GUID helper (16-byte struct laid out manually)
// ============================================================
/**
 * Allocate a GUID (16 bytes) in the current [MemScope].
 *
 * Layout:
 *   Offset 0:  Data1 (DWORD, 4 bytes, little-endian)
 *   Offset 4:  Data2 (WORD,  2 bytes, little-endian)
 *   Offset 6:  Data3 (WORD,  2 bytes, little-endian)
 *   Offset 8:  Data4 (BYTE[8], as-is)
 */
private fun MemScope.guid(
    d1: UInt, d2: UShort, d3: UShort,
    b0: UByte, b1: UByte, b2: UByte, b3: UByte,
    b4: UByte, b5: UByte, b6: UByte, b7: UByte
): CPointer<ByteVar> {
    val buf = allocArray<ByteVar>(GUID_SIZE)
    // Data1 (little-endian)
    buf[0]  = (d1         and 0xFFu).toByte()
    buf[1]  = ((d1 shr 8)  and 0xFFu).toByte()
    buf[2]  = ((d1 shr 16) and 0xFFu).toByte()
    buf[3]  = ((d1 shr 24) and 0xFFu).toByte()
    // Data2 (little-endian)
    buf[4]  = (d2         and 0xFFu).toByte()
    buf[5]  = ((d2.toUInt() shr 8) and 0xFFu).toByte()
    // Data3 (little-endian)
    buf[6]  = (d3         and 0xFFu).toByte()
    buf[7]  = ((d3.toUInt() shr 8) and 0xFFu).toByte()
    // Data4
    buf[8]  = b0.toByte()
    buf[9]  = b1.toByte()
    buf[10] = b2.toByte()
    buf[11] = b3.toByte()
    buf[12] = b4.toByte()
    buf[13] = b5.toByte()
    buf[14] = b6.toByte()
    buf[15] = b7.toByte()
    return buf
}

// ============================================================
// Dynamic loading of WinRT functions from combase.dll
// ============================================================
private val combaseDll: HMODULE = LoadLibraryW("combase.dll")
    ?: error("Failed to load combase.dll")

private fun proc(name: String): COpaquePointer =
    GetProcAddress(combaseDll, name)
        ?: error("GetProcAddress failed: $name")

// RoInitialize(UINT initType) -> HRESULT
private typealias FnRoInitialize = CFunction<(UInt) -> Int>
private val pfnRoInitialize: CPointer<FnRoInitialize> =
    proc("RoInitialize").reinterpret()

// RoUninitialize() -> void
private typealias FnRoUninitialize = CFunction<() -> Unit>
private val pfnRoUninitialize: CPointer<FnRoUninitialize> =
    proc("RoUninitialize").reinterpret()

// WindowsCreateStringReference(PCWSTR str, UINT32 len, HSTRING_HEADER* hdr, HSTRING* hs) -> HRESULT
//   HSTRING_HEADER = opaque 40 bytes, HSTRING = void*
private typealias FnWindowsCreateStringReference =
    CFunction<(COpaquePointer?, UInt, COpaquePointer, CPointer<COpaquePointerVar>) -> Int>
private val pfnWindowsCreateStringReference: CPointer<FnWindowsCreateStringReference> =
    proc("WindowsCreateStringReference").reinterpret()

// RoActivateInstance(HSTRING classId, IInspectable** instance) -> HRESULT
private typealias FnRoActivateInstance =
    CFunction<(COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>
private val pfnRoActivateInstance: CPointer<FnRoActivateInstance> =
    proc("RoActivateInstance").reinterpret()

// RoGetActivationFactory(HSTRING classId, REFIID iid, void** factory) -> HRESULT
//   REFIID is a pointer to GUID (16 bytes) — passed as COpaquePointer
private typealias FnRoGetActivationFactory =
    CFunction<(COpaquePointer?, COpaquePointer, CPointer<COpaquePointerVar>) -> Int>
private val pfnRoGetActivationFactory: CPointer<FnRoGetActivationFactory> =
    proc("RoGetActivationFactory").reinterpret()

// ============================================================
// HSTRING helper
// ============================================================
/**
 * Create an HSTRING reference from a Kotlin string.
 *
 * WindowsCreateStringReference does NOT copy the string;
 * the returned HSTRING is valid only while the wcstr buffer
 * and header remain alive in the current memScoped block.
 *
 * @return HSTRING (as COpaquePointer?)
 */
private fun MemScope.createHString(str: String): COpaquePointer? {
    val wstr = str.wcstr.ptr  // CPointer<UShortVar> — subtype of COpaquePointer
    val header = allocArray<ByteVar>(HSTRING_HEADER_SIZE)
    val hstring = alloc<COpaquePointerVar>()

    val hr = pfnWindowsCreateStringReference(
        wstr,
        str.length.toUInt(),
        header,
        hstring.ptr
    )
    check(hr == S_OK) {
        "WindowsCreateStringReference failed: 0x${hr.toUInt().toString(16)}"
    }
    return hstring.value
}

// ============================================================
// COM VTable helpers
// ============================================================
/**
 * Read a function pointer from a COM object's VTable at [index].
 *
 * Memory layout:
 *   comPtr  -> [ vtable_ptr, ... ]
 *   vtable  -> [ fn0, fn1, fn2, fn3, ... ]
 *
 * Each entry is a pointer-sized value (8 bytes on x64).
 */
private fun getVTableEntry(comPtr: COpaquePointer, index: Int): COpaquePointer {
    // Step 1: Read vtable pointer (first pointer at comPtr)
    val vtablePtr: COpaquePointer =
        comPtr.reinterpret<COpaquePointerVar>().pointed.value
            ?: error("VTable pointer is null")
    // Step 2: Read function pointer at vtable[index]
    val entryPtr: CPointer<COpaquePointerVar> =
        (vtablePtr.reinterpret<COpaquePointerVar>() + index)
            ?: error("VTable arithmetic failed at index $index")
    return entryPtr.pointed.value
        ?: error("VTable entry [$index] is null")
}

/**
 * IUnknown::Release (VTable index 2)
 * Signature: ULONG Release(this)
 */
private fun comRelease(obj: COpaquePointer?) {
    if (obj == null) return
    val fn = getVTableEntry(obj, 2)
        .reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
    fn(obj)
}

/**
 * IUnknown::QueryInterface (VTable index 0)
 * Signature: HRESULT QueryInterface(this, REFIID riid, void** ppvObject)
 */
private fun comQueryInterface(obj: COpaquePointer, iid: COpaquePointer): COpaquePointer {
    memScoped {
        val result = alloc<COpaquePointerVar>()
        val fn = getVTableEntry(obj, 0)
            .reinterpret<CFunction<(COpaquePointer?, COpaquePointer, CPointer<COpaquePointerVar>) -> Int>>()
        val hr = fn(obj, iid, result.ptr)
        check(hr == S_OK) {
            "QueryInterface failed: 0x${hr.toUInt().toString(16)}"
        }
        return result.value ?: error("QueryInterface returned null")
    }
}

// ============================================================
// Create XML Document from string
// ============================================================
/**
 * Activate Windows.Data.Xml.Dom.XmlDocument and load XML content.
 *
 * IXmlDocumentIO VTable:
 *   [0-2] IUnknown
 *   [3-5] IInspectable
 *   [6]   LoadXml(HSTRING)
 */
private fun MemScope.createXmlDocumentFromString(xmlString: String): COpaquePointer {
    // Activate XmlDocument
    val hsClass = createHString(RC_XmlDocument)
    val inspectable = alloc<COpaquePointerVar>()
    val hr = pfnRoActivateInstance(hsClass, inspectable.ptr)
    check(hr == S_OK) {
        "RoActivateInstance(XmlDocument) failed: 0x${hr.toUInt().toString(16)}"
    }
    val pInspectable = inspectable.value ?: error("RoActivateInstance returned null")
    println("[KtToast] XmlDocument activated")

    // QueryInterface -> IXmlDocument
    val iidXmlDoc = guid(
        0xf7f3a506u, 0x1e87u, 0x42d6u,
        0xbcu, 0xfbu, 0xb8u, 0xc8u, 0x09u, 0xfau, 0x54u, 0x94u
    )
    val xmlDoc = comQueryInterface(pInspectable, iidXmlDoc)
    comRelease(pInspectable)

    // QueryInterface -> IXmlDocumentIO
    val iidDocIO = guid(
        0x6cd0e74eu, 0xee65u, 0x4489u,
        0x9eu, 0xbfu, 0xcau, 0x43u, 0xe8u, 0x7bu, 0xa6u, 0x37u
    )
    val xmlDocIO = comQueryInterface(xmlDoc, iidDocIO)

    // IXmlDocumentIO::LoadXml (VTable index 6)
    val hsXml = createHString(xmlString)
    val loadXml = getVTableEntry(xmlDocIO, 6)
        .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
    val hrLoad = loadXml(xmlDocIO, hsXml)
    check(hrLoad == S_OK) {
        "IXmlDocumentIO::LoadXml failed: 0x${hrLoad.toUInt().toString(16)}"
    }
    println("[KtToast] XML loaded successfully")

    comRelease(xmlDocIO)
    return xmlDoc
}

// ============================================================
// Main
// ============================================================
fun main() {
    println("[KtToast] === Starting Toast Notification ===")

    // Initialize WinRT
    val hrInit = pfnRoInitialize(RO_INIT_MULTITHREADED)
    check(hrInit == S_OK || hrInit == S_FALSE) {
        "RoInitialize failed: 0x${hrInit.toUInt().toString(16)}"
    }
    println("[KtToast] WinRT initialized")

    try {
        memScoped {
            // ── Create XML Document ──
            val xmlString =
                "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n" +
                "  <visual>\r\n" +
                "    <binding template=\"ToastGeneric\">\r\n" +
                "      <text><![CDATA[Hello, WinRT World!]]></text>\r\n" +
                "    </binding>\r\n" +
                "  </visual>\r\n" +
                "  <audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n" +
                "</toast>\r\n"
            val inputXml = createXmlDocumentFromString(xmlString)

            // ── Get ToastNotificationManagerStatics ──
            val hsMgr = createHString(RC_ToastNotificationManager)
            val iidToastStatics = guid(
                0x50ac103fu, 0xd235u, 0x4598u,
                0xbbu, 0xefu, 0x98u, 0xfeu, 0x4du, 0x1au, 0x3au, 0xd4u
            )
            val toastStatics = alloc<COpaquePointerVar>()
            var hr = pfnRoGetActivationFactory(hsMgr, iidToastStatics, toastStatics.ptr)
            check(hr == S_OK) {
                "RoGetActivationFactory(ToastNotificationManager) failed: 0x${hr.toUInt().toString(16)}"
            }
            val pToastStatics = toastStatics.value!!
            println("[KtToast] ToastNotificationManagerStatics acquired")

            // ── CreateToastNotifierWithId (VTable index 7) ──
            // IToastNotificationManagerStatics:
            //   [0-2] IUnknown  [3-5] IInspectable
            //   [6] CreateToastNotifier()
            //   [7] CreateToastNotifierWithId(HSTRING appId, out IToastNotifier*)
            val hsAppId = createHString(APP_ID)
            println("[KtToast] Using App ID: $APP_ID")
            val notifierVar = alloc<COpaquePointerVar>()
            val createNotifierWithId = getVTableEntry(pToastStatics, 7)
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>>()
            hr = createNotifierWithId(pToastStatics, hsAppId, notifierVar.ptr)
            check(hr == S_OK) {
                "CreateToastNotifierWithId failed: 0x${hr.toUInt().toString(16)}"
            }
            val notifier = notifierVar.value!!
            println("[KtToast] ToastNotifier created")

            // ── Get ToastNotificationFactory ──
            val hsTN = createHString(RC_ToastNotification)
            val iidToastFactory = guid(
                0x04124b20u, 0x82c6u, 0x4229u,
                0xb1u, 0x09u, 0xfdu, 0x9eu, 0xd4u, 0x66u, 0x2bu, 0x53u
            )
            val notifFactory = alloc<COpaquePointerVar>()
            hr = pfnRoGetActivationFactory(hsTN, iidToastFactory, notifFactory.ptr)
            check(hr == S_OK) {
                "RoGetActivationFactory(ToastNotification) failed: 0x${hr.toUInt().toString(16)}"
            }
            val pNotifFactory = notifFactory.value!!
            println("[KtToast] ToastNotificationFactory acquired")

            // ── CreateToastNotification (VTable index 6) ──
            // IToastNotificationFactory:
            //   [0-2] IUnknown  [3-5] IInspectable
            //   [6] CreateToastNotification(IXmlDocument*, out IToastNotification*)
            val toastVar = alloc<COpaquePointerVar>()
            val createToast = getVTableEntry(pNotifFactory, 6)
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?, CPointer<COpaquePointerVar>) -> Int>>()
            hr = createToast(pNotifFactory, inputXml, toastVar.ptr)
            check(hr == S_OK) {
                "CreateToastNotification failed: 0x${hr.toUInt().toString(16)}"
            }
            val toast = toastVar.value!!
            println("[KtToast] ToastNotification created")

            // ── IToastNotifier::Show (VTable index 6) ──
            // IToastNotifier:
            //   [0-2] IUnknown  [3-5] IInspectable
            //   [6] Show(IToastNotification*)
            val showFn = getVTableEntry(notifier, 6)
                .reinterpret<CFunction<(COpaquePointer?, COpaquePointer?) -> Int>>()
            hr = showFn(notifier, toast)
            check(hr == S_OK) {
                "IToastNotifier::Show failed: 0x${hr.toUInt().toString(16)}"
            }
            println("[KtToast] Toast notification shown!")

            Sleep(1000u)

            // Cleanup (release in reverse order)
            comRelease(toast)
            comRelease(pNotifFactory)
            comRelease(notifier)
            comRelease(pToastStatics)
            comRelease(inputXml)

            println("[KtToast] === Toast Notification Complete ===")
        }
    } finally {
        pfnRoUninitialize()
        println("[KtToast] WinRT uninitialized")
    }
}