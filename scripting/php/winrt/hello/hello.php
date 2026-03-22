<?php
declare(strict_types=1);

/**
 * WinRT Toast Notification (PHP FFI only, no external libraries)
 *
 * COM vtable calling pattern from the proven DirectX 11 PHP FFI sample:
 *   1. IUnknown struct with void** lpVtbl
 *   2. __stdcall function pointer typedefs
 *   3. FFI::cast($scope->type('Typedef'), $obj->lpVtbl[INDEX])
 *   4. GUID struct + FFI::addr() for IID parameters
 *
 * CRITICAL: FFI::cast() does NOT copy memory. It creates a "view" of
 * the same underlying bytes. If the original CData (e.g. a local void*)
 * is garbage-collected, the cast result becomes a dangling pointer.
 * All CData whose cast results outlive the current scope MUST be kept
 * alive in $gc_guard.
 *
 * Requirements:
 *   - Windows 10/11, x64
 *   - PHP 7.4+ (64-bit) with FFI enabled (ffi.enable=true in php.ini)
 *
 * Usage:
 *   php hello.php
 */

// ============================================================
// Trace helper
// ============================================================
function trace(string $msg): void
{
    echo "[PhpToast] {$msg}\n";
    if (function_exists('ob_flush')) { @ob_flush(); }
    flush();
}

trace('=== Script started ===');
trace('PHP ' . PHP_VERSION . ' (' . PHP_INT_SIZE * 8 . '-bit) on ' . PHP_OS);

if (!extension_loaded('ffi')) {
    trace('FATAL: FFI extension not loaded');
    exit(1);
}
trace('FFI extension: OK');

// ============================================================
// Constants
// ============================================================
const S_OK    = 0;
const S_FALSE = 1;
const HSTRING_HEADER_SIZE = 8 * 5;
const APP_ID  = '0123456789ABCDEF';

const RUNTIMECLASS_XML_DOCUMENT        = 'Windows.Data.Xml.Dom.XmlDocument';
const RUNTIMECLASS_TOAST_MANAGER       = 'Windows.UI.Notifications.ToastNotificationManager';
const RUNTIMECLASS_TOAST_NOTIFICATION  = 'Windows.UI.Notifications.ToastNotification';

// COM VTable slot indices
const VTBL_QI      = 0;
const VTBL_RELEASE = 2;
const VTBL_LOAD_XML = 6;
const VTBL_CREATE_NOTIFIER_WITH_ID = 7;
const VTBL_CREATE_TOAST = 6;
const VTBL_SHOW = 6;

// ============================================================
// COM type scope (type-only, no DLL)
// ============================================================
trace('Defining COM types ...');
$sizeType = PHP_INT_SIZE === 8 ? 'unsigned long long' : 'unsigned long';
$comTypes = FFI::cdef(<<<CDEF
    typedef {$sizeType} UINTPTR;
    typedef long HRESULT;

    typedef struct _GUID {
        uint32_t Data1;
        uint16_t Data2;
        uint16_t Data3;
        uint8_t  Data4[8];
    } GUID;

    typedef struct IUnknown {
        void** lpVtbl;
    } IUnknown;

    typedef HRESULT  (__stdcall *QueryInterfaceFunc)(void *pThis, const GUID *riid, void **ppvObj);
    typedef uint32_t (__stdcall *ReleaseFunc)(void *pThis);
    typedef HRESULT  (__stdcall *LoadXmlFunc)(void *pThis, void *hstrXml);
    typedef HRESULT  (__stdcall *CreateToastNotifierWithIdFunc)(void *pThis, void *hstrAppId, void **ppNotifier);
    typedef HRESULT  (__stdcall *CreateToastNotificationFunc)(void *pThis, void *pXmlDoc, void **ppToast);
    typedef HRESULT  (__stdcall *ShowFunc)(void *pThis, void *pToast);
CDEF);
trace('COM types: OK');

// ============================================================
// DLL imports
// ============================================================
trace('Loading DLLs ...');
$shell32 = FFI::cdef(<<<'C'
    int32_t SetCurrentProcessExplicitAppUserModelID(const uint16_t *appId);
C, 'shell32.dll');
trace('  shell32.dll: OK');

$combase = FFI::cdef(<<<'C'
    int32_t RoInitialize(uint32_t initType);
    void    RoUninitialize(void);
    int32_t WindowsCreateStringReference(
        const uint16_t *sourceString,
        uint32_t length,
        uint8_t *hstringHeader,
        void **string
    );
    int32_t RoActivateInstance(void *classId, void **instance);
    int32_t RoGetActivationFactory(void *classId, void *iid, void **factory);
C, 'combase.dll');
trace('  combase.dll: OK');

// ============================================================
// GC guard: prevent garbage collection of CData whose memory
// is referenced by other CData (FFI::cast views, returned ptrs).
// ============================================================
$gc_guard = [];

// ============================================================
// Buffer helpers
// ============================================================

function wbuf(string $s): FFI\CData
{
    global $gc_guard;
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    $gc_guard[] = $buf;
    return $buf;
}

function zbuf(int $size): FFI\CData
{
    global $gc_guard;
    $buf = FFI::new("uint8_t[$size]", false);
    FFI::memcpy($buf, str_repeat("\0", $size), $size);
    $gc_guard[] = $buf;
    return $buf;
}

// ============================================================
// GUID helper (mirrors DirectX sample's guid_from_string)
// ============================================================
function make_guid_struct(int $d1, int $d2, int $d3, int ...$d4): FFI\CData
{
    global $comTypes, $gc_guard;
    $g = $comTypes->new('GUID');
    $g->Data1 = $d1;
    $g->Data2 = $d2;
    $g->Data3 = $d3;
    for ($i = 0; $i < 8; $i++) {
        $g->Data4[$i] = $d4[$i];
    }
    $gc_guard[] = $g;
    return $g;
}

$IID_IToastNotificationManagerStatics = make_guid_struct(
    0x50ac103f, 0xd235, 0x4598,
    0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4
);
$IID_IToastNotificationFactory = make_guid_struct(
    0x04124b20, 0x82c6, 0x4229,
    0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53
);
$IID_IXmlDocument = make_guid_struct(
    0xf7f3a506, 0x1e87, 0x42d6,
    0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94
);
$IID_IXmlDocumentIO = make_guid_struct(
    0x6cd0e74e, 0xee65, 0x4489,
    0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37
);
trace('GUIDs: OK');

// ============================================================
// HSTRING helper
// ============================================================
function create_hstring(string $str): FFI\CData
{
    global $combase, $gc_guard;
    trace("  create_hstring('" . substr($str, 0, 50) . "'" .
          (strlen($str) > 50 ? '...' : '') . ')');

    $wstr   = wbuf($str);
    $header = zbuf(HSTRING_HEADER_SIZE);
    $hs_out = FFI::new('void*');

    $hr = $combase->WindowsCreateStringReference(
        $wstr, strlen($str), $header, FFI::addr($hs_out)
    );
    if ($hr !== S_OK) {
        throw new RuntimeException(sprintf(
            'WindowsCreateStringReference failed: 0x%08X', $hr & 0xFFFFFFFF
        ));
    }

    // CRITICAL: Keep $hs_out alive - FFI::cast() views same memory.
    // If $hs_out is GC'd, any cast result becomes a dangling pointer.
    $gc_guard[] = $hs_out;
    trace("    OK");
    return $hs_out;
}

// ============================================================
// COM helpers (DirectX sample pattern)
// ============================================================

function com_release(FFI\CData $obj): void
{
    global $comTypes;
    try {
        if ((int) FFI::cast($comTypes->type('UINTPTR'), $obj)->cdata === 0) return;
        $fn = FFI::cast($comTypes->type('ReleaseFunc'), $obj->lpVtbl[VTBL_RELEASE]);
        $fn($obj);
    } catch (\Throwable $e) {
        trace("    com_release ignored: " . $e->getMessage());
    }
}

/**
 * IUnknown::QueryInterface
 *
 * CRITICAL: $out (FFI::new('void*')) must be kept alive in gc_guard
 * because FFI::cast('IUnknown*', $out) creates a VIEW of $out's
 * memory, not a copy. If $out is GC'd when this function returns,
 * the returned IUnknown* becomes a dangling pointer.
 */
function com_query_interface(FFI\CData $obj, FFI\CData $guid): FFI\CData
{
    global $comTypes, $gc_guard;
    trace("  QueryInterface ...");

    $out = FFI::new('void*');

    $fn = FFI::cast($comTypes->type('QueryInterfaceFunc'), $obj->lpVtbl[VTBL_QI]);
    trace("    calling QI ...");
    $hr = $fn($obj, FFI::addr($guid), FFI::addr($out));
    trace("    QI returned hr=0x" . sprintf('%08X', $hr & 0xFFFFFFFF));

    if ($hr !== S_OK) {
        throw new RuntimeException(sprintf(
            'QueryInterface failed: 0x%08X', $hr & 0xFFFFFFFF
        ));
    }

    // CRITICAL: Keep $out alive so the IUnknown* cast doesn't dangle
    $gc_guard[] = $out;

    $result = FFI::cast($comTypes->type('IUnknown*'), $out);
    trace("    OK");
    return $result;
}

// ============================================================
// Create IXmlDocument from XML string
// ============================================================
function create_xml_document_from_string(string $xml_string): FFI\CData
{
    global $comTypes, $combase, $gc_guard;
    global $IID_IXmlDocument, $IID_IXmlDocumentIO;
    trace('create_xml_document_from_string ...');

    $hs_class    = create_hstring(RUNTIMECLASS_XML_DOCUMENT);
    $inspectable = FFI::new('void*');
    trace('  RoActivateInstance ...');
    $hr = $combase->RoActivateInstance($hs_class, FFI::addr($inspectable));
    if ($hr !== S_OK) {
        throw new RuntimeException(sprintf(
            'RoActivateInstance(XmlDocument) failed: 0x%08X', $hr & 0xFFFFFFFF
        ));
    }
    trace('  RoActivateInstance: OK');

    // Keep alive + wrap as IUnknown*
    $gc_guard[] = $inspectable;
    $inspObj = FFI::cast($comTypes->type('IUnknown*'), $inspectable);

    // QueryInterface for IXmlDocument
    $xml_doc = com_query_interface($inspObj, $IID_IXmlDocument);
    com_release($inspObj);

    // QueryInterface for IXmlDocumentIO
    $xml_doc_io = com_query_interface($xml_doc, $IID_IXmlDocumentIO);

    // IXmlDocumentIO::LoadXml (slot 6)
    $hs_xml = create_hstring($xml_string);
    trace('  LoadXml (slot 6) ...');
    $fn_load = FFI::cast($comTypes->type('LoadXmlFunc'), $xml_doc_io->lpVtbl[VTBL_LOAD_XML]);
    $hr = $fn_load($xml_doc_io, $hs_xml);
    if ($hr !== S_OK) {
        throw new RuntimeException(sprintf(
            'LoadXml failed: 0x%08X', $hr & 0xFFFFFFFF
        ));
    }
    trace('  LoadXml: OK');

    com_release($xml_doc_io);
    return $xml_doc;
}

// ============================================================
// Main
// ============================================================
function main(): void
{
    global $comTypes, $combase, $shell32, $gc_guard;
    global $IID_IToastNotificationManagerStatics, $IID_IToastNotificationFactory;

    trace('--- main() entered ---');

    // Set AppUserModelID
    trace('SetCurrentProcessExplicitAppUserModelID ...');
    $hr = $shell32->SetCurrentProcessExplicitAppUserModelID(wbuf(APP_ID));
    trace(sprintf('  result: 0x%08X', $hr & 0xFFFFFFFF));

    // Initialize WinRT
    trace('RoInitialize ...');
    $hr = $combase->RoInitialize(1);
    if ($hr !== S_OK && $hr !== S_FALSE) {
        throw new RuntimeException(sprintf('RoInitialize failed: 0x%08X', $hr & 0xFFFFFFFF));
    }
    trace(sprintf('  result: 0x%08X (OK)', $hr & 0xFFFFFFFF));

    try {
        $xml_string =
            "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n" .
            "\t<visual>\r\n" .
            "\t\t<binding template=\"ToastGeneric\">\r\n" .
            "\t\t\t<text><![CDATA[Hello, WinRT(PHP) World!]]></text>\r\n" .
            "\t\t</binding>\r\n" .
            "\t</visual>\r\n" .
            "\t<audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n" .
            "</toast>\r\n";

        // Step 1: XmlDocument
        trace('--- Step 1: Create XmlDocument ---');
        $input_xml = create_xml_document_from_string($xml_string);
        trace('XmlDocument: OK');

        // Step 2: ToastNotificationManager factory
        trace('--- Step 2: ToastNotificationManager factory ---');
        $hs_tnm      = create_hstring(RUNTIMECLASS_TOAST_MANAGER);
        $statics_out  = FFI::new('void*');

        trace('  RoGetActivationFactory ...');
        $hr = $combase->RoGetActivationFactory(
            $hs_tnm,
            FFI::addr($IID_IToastNotificationManagerStatics),
            FFI::addr($statics_out)
        );
        if ($hr !== S_OK) {
            throw new RuntimeException(sprintf(
                'RoGetActivationFactory(ToastNotificationManager) failed: 0x%08X',
                $hr & 0xFFFFFFFF
            ));
        }
        $gc_guard[] = $statics_out;
        $toast_statics = FFI::cast($comTypes->type('IUnknown*'), $statics_out);
        trace('  IToastNotificationManagerStatics: OK');

        // Step 3: CreateToastNotifierWithId (slot 7)
        trace('--- Step 3: CreateToastNotifierWithId ---');
        $hs_appid     = create_hstring(APP_ID);
        $notifier_out = FFI::new('void*');

        $fn_create_notifier = FFI::cast(
            $comTypes->type('CreateToastNotifierWithIdFunc'),
            $toast_statics->lpVtbl[VTBL_CREATE_NOTIFIER_WITH_ID]
        );
        trace('  calling ...');
        $hr = $fn_create_notifier($toast_statics, $hs_appid, FFI::addr($notifier_out));
        if ($hr !== S_OK) {
            throw new RuntimeException(sprintf(
                'CreateToastNotifierWithId failed: 0x%08X', $hr & 0xFFFFFFFF
            ));
        }
        $gc_guard[] = $notifier_out;
        $notifier = FFI::cast($comTypes->type('IUnknown*'), $notifier_out);
        trace('  IToastNotifier: OK');

        // Step 4: ToastNotification factory
        trace('--- Step 4: ToastNotification factory ---');
        $hs_tn       = create_hstring(RUNTIMECLASS_TOAST_NOTIFICATION);
        $factory_out  = FFI::new('void*');

        $hr = $combase->RoGetActivationFactory(
            $hs_tn,
            FFI::addr($IID_IToastNotificationFactory),
            FFI::addr($factory_out)
        );
        if ($hr !== S_OK) {
            throw new RuntimeException(sprintf(
                'RoGetActivationFactory(ToastNotification) failed: 0x%08X',
                $hr & 0xFFFFFFFF
            ));
        }
        $gc_guard[] = $factory_out;
        $notif_factory = FFI::cast($comTypes->type('IUnknown*'), $factory_out);
        trace('  IToastNotificationFactory: OK');

        // Step 5: CreateToastNotification (slot 6)
        trace('--- Step 5: CreateToastNotification ---');
        $toast_out = FFI::new('void*');

        $fn_create_toast = FFI::cast(
            $comTypes->type('CreateToastNotificationFunc'),
            $notif_factory->lpVtbl[VTBL_CREATE_TOAST]
        );
        trace('  calling ...');
        $hr = $fn_create_toast($notif_factory, $input_xml, FFI::addr($toast_out));
        if ($hr !== S_OK) {
            throw new RuntimeException(sprintf(
                'CreateToastNotification failed: 0x%08X', $hr & 0xFFFFFFFF
            ));
        }
        $gc_guard[] = $toast_out;
        $toast = FFI::cast($comTypes->type('IUnknown*'), $toast_out);
        trace('  IToastNotification: OK');

        // Step 6: Show (slot 6)
        trace('--- Step 6: Show ---');
        $fn_show = FFI::cast(
            $comTypes->type('ShowFunc'),
            $notifier->lpVtbl[VTBL_SHOW]
        );
        trace('  calling ...');
        $hr = $fn_show($notifier, $toast);
        if ($hr !== S_OK) {
            throw new RuntimeException(sprintf(
                'Show failed: 0x%08X', $hr & 0xFFFFFFFF
            ));
        }
        trace('Toast notification shown!');

        echo "\nPress Enter to exit...\n";
        fgets(STDIN);

        // Cleanup
        trace('--- Cleanup ---');
        com_release($toast);          trace('  toast released');
        com_release($notif_factory);  trace('  factory released');
        com_release($notifier);       trace('  notifier released');
        com_release($toast_statics);  trace('  statics released');
        com_release($input_xml);      trace('  xml_doc released');

        trace('=== Toast Notification Complete ===');

    } catch (\Throwable $e) {
        trace('ERROR: ' . $e->getMessage());
        trace('  at ' . $e->getFile() . ':' . $e->getLine());
        trace('  ' . $e->getTraceAsString());
    } finally {
        trace('RoUninitialize ...');
        $combase->RoUninitialize();
        trace('WinRT uninitialized');
    }
}

main();
