<?php
declare(strict_types=1);

/*
  COM Early Binding via PHP FFI
  
  Calls IShellDispatch::BrowseForFolder using vtable (early binding).
  Equivalent to the C version using lpVtbl->BrowseForFolder.
*/

// COM constants
const CLSCTX_INPROC_SERVER = 1;
const VT_I4 = 3;
const ssfWINDOWS = 36;  // Windows folder

// GUID helper
function makeGUID(int $d1, int $d2, int $d3, array $d4): FFI\CData
{
    global $ole32;
    $guid = $ole32->new('GUID');
    $guid->Data1 = $d1;
    $guid->Data2 = $d2;
    $guid->Data3 = $d3;
    for ($i = 0; $i < 8; $i++) {
        $guid->Data4[$i] = $d4[$i];
    }
    return $guid;
}

// Wide string helper
function wstr(string $s): FFI\CData
{
    $bytes = iconv('UTF-8', 'UTF-16LE', $s) . "\x00\x00";
    $len16 = intdiv(strlen($bytes), 2);
    $buf = FFI::new("uint16_t[$len16]", false);
    FFI::memcpy($buf, $bytes, strlen($bytes));
    return $buf;
}

// ole32.dll
$ole32 = FFI::cdef('
    typedef unsigned long DWORD;
    typedef long LONG;
    typedef long HRESULT;
    typedef void* LPVOID;

    typedef struct _GUID {
        uint32_t Data1;
        uint16_t Data2;
        uint16_t Data3;
        uint8_t  Data4[8];
    } GUID;

    HRESULT CoInitialize(LPVOID pvReserved);
    void CoUninitialize(void);
    HRESULT CoCreateInstance(
        const GUID* rclsid,
        LPVOID pUnkOuter,
        DWORD dwClsContext,
        const GUID* riid,
        LPVOID* ppv
    );
', 'ole32.dll');

// oleaut32.dll for VARIANT and BSTR functions
$oleaut32 = FFI::cdef('
    typedef uint16_t* BSTR;
    typedef long LONG;
    typedef long HRESULT;

    // VARIANT structure
    typedef struct tagVARIANT {
        uint16_t vt;
        uint16_t wReserved1;
        uint16_t wReserved2;
        uint16_t wReserved3;
        union {
            LONG lVal;
            int64_t llVal;
            void* pval;
        };
    } VARIANT;

    BSTR SysAllocString(const uint16_t* psz);
    void SysFreeString(BSTR bstrString);
    void VariantInit(VARIANT* pvarg);
    HRESULT VariantClear(VARIANT* pvarg);
', 'oleaut32.dll');

// Define COM interface structures as pointer arrays (vtable approach)
// We'll access vtable entries by index and cast to function pointers

$comTypes = FFI::cdef('
    typedef long HRESULT;
    typedef long LONG;
    typedef void* HWND;
    typedef uint16_t* BSTR;

    typedef struct tagVARIANT {
        uint16_t vt;
        uint16_t wReserved1;
        uint16_t wReserved2;
        uint16_t wReserved3;
        union {
            LONG lVal;
            int64_t llVal;
            void* pval;
        };
    } VARIANT;

    // COM object is just a pointer to vtable pointer
    typedef struct IUnknown {
        void** lpVtbl;
    } IUnknown;

    // Function pointer types
    typedef HRESULT (__stdcall *ReleaseFunc)(void* pThis);
    typedef HRESULT (__stdcall *BrowseForFolderFunc)(void* pThis, LONG Hwnd, BSTR Title, LONG Options, VARIANT RootFolder, void** ppsdf);
');

// Initialize COM
$hr = $ole32->CoInitialize(null);
if ($hr < 0) {
    echo "CoInitialize failed: " . sprintf("0x%08X", $hr) . "\n";
    exit(1);
}
echo "COM initialized\n";

// CLSID_Shell: {13709620-C279-11CE-A49E-444553540000}
$clsidShell = makeGUID(
    0x13709620,
    0xC279,
    0x11CE,
    [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00]
);

// IID_IShellDispatch: {D8F015C0-C278-11CE-A49E-444553540000}
$iidShellDispatch = makeGUID(
    0xD8F015C0,
    0xC278,
    0x11CE,
    [0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00]
);

// Create Shell object
$ppShell = FFI::new('void*');
$hr = $ole32->CoCreateInstance(
    FFI::addr($clsidShell),
    null,
    CLSCTX_INPROC_SERVER,
    FFI::addr($iidShellDispatch),
    FFI::addr($ppShell)
);

if ($hr < 0) {
    echo "CoCreateInstance failed: " . sprintf("0x%08X", $hr) . "\n";
    $ole32->CoUninitialize();
    exit(1);
}
echo "IShellDispatch created\n";

// Cast to IUnknown to access vtable
$pShell = FFI::cast($comTypes->type('IUnknown*'), $ppShell);
echo "IShellDispatch vtable accessed\n";

// Get vtable pointer
$vtbl = $pShell->lpVtbl;

// vtable indices:
// 0: QueryInterface, 1: AddRef, 2: Release
// 3: GetTypeInfoCount, 4: GetTypeInfo, 5: GetIDsOfNames, 6: Invoke
// 7: Application, 8: Parent, 9: NameSpace, 10: BrowseForFolder
const VTBL_RELEASE = 2;
const VTBL_BROWSEFORFOLDER = 10;

// Initialize VARIANT for RootFolder
$vRootFolder = $oleaut32->new('VARIANT');
$oleaut32->VariantInit(FFI::addr($vRootFolder));
$vRootFolder->vt = VT_I4;
$vRootFolder->lVal = ssfWINDOWS;

// Create BSTR title
$titleStr = wstr("Hello, COM World!");
$bstrTitle = $oleaut32->SysAllocString(FFI::cast('uint16_t*', FFI::addr($titleStr[0])));
echo "BSTR title created\n";

// Prepare output folder pointer
$ppFolder = FFI::new('void*');

// Create VARIANT for passing to BrowseForFolder
$vRoot = $comTypes->new('VARIANT');
$vRoot->vt = VT_I4;
$vRoot->lVal = ssfWINDOWS;

echo "Calling BrowseForFolder...\n";

// Get BrowseForFolder function pointer from vtable and cast it
$pfnBrowseForFolder = FFI::cast(
    $comTypes->type('BrowseForFolderFunc'),
    $vtbl[VTBL_BROWSEFORFOLDER]
);

// Call BrowseForFolder via function pointer
$hr = $pfnBrowseForFolder(
    $pShell,            // pThis
    0,                  // HWND
    $bstrTitle,         // Title
    0,                  // Options
    $vRoot,             // RootFolder (passed by value)
    FFI::addr($ppFolder)
);

echo "BrowseForFolder returned: " . sprintf("0x%08X", $hr) . "\n";

// Free BSTR
$oleaut32->SysFreeString($bstrTitle);

// Clear VARIANT
$oleaut32->VariantClear(FFI::addr($vRootFolder));

// Release Folder if returned
if ($ppFolder !== null && FFI::cast('uintptr_t', $ppFolder)->cdata !== 0) {
    echo "Folder selected, releasing...\n";
    $pFolder = FFI::cast($comTypes->type('IUnknown*'), $ppFolder);
    $pfnRelease = FFI::cast($comTypes->type('ReleaseFunc'), $pFolder->lpVtbl[VTBL_RELEASE]);
    $pfnRelease($pFolder);
}

// Release IShellDispatch
echo "Releasing IShellDispatch...\n";
$pfnRelease = FFI::cast($comTypes->type('ReleaseFunc'), $vtbl[VTBL_RELEASE]);
$pfnRelease($pShell);

// Uninitialize COM
$ole32->CoUninitialize();
echo "COM uninitialized\n";

echo "Program ended normally\n";
