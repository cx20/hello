# -*- coding: utf-8 -*-
import ctypes
from ctypes import wintypes

# ============================================================
# DLLs (COM core + OLE Automation)
# ============================================================
ole32    = ctypes.WinDLL("ole32", use_last_error=True)
oleaut32 = ctypes.WinDLL("oleaut32", use_last_error=True)

HRESULT = wintypes.LONG
LCID    = wintypes.DWORD
DISPID  = wintypes.LONG
WORD    = wintypes.WORD
UINT    = wintypes.UINT

# ============================================================
# GUID
# ============================================================
class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]

def guid_from_str(s: str) -> GUID:
    """Convert '{xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}' to GUID struct (bytes_le)."""
    import uuid
    u = uuid.UUID(s)
    g = GUID()
    ctypes.memmove(ctypes.byref(g), u.bytes_le, ctypes.sizeof(GUID))
    return g

IID_IDispatch = guid_from_str("{00020400-0000-0000-C000-000000000046}")

# IID_NULL for IDispatch::GetIDsOfNames / Invoke must be all-zeros.
IID_NULL = GUID()

# ============================================================
# COM APIs
# ============================================================
ole32.CoInitialize.argtypes = (ctypes.c_void_p,)
ole32.CoInitialize.restype  = HRESULT

ole32.CoUninitialize.argtypes = ()
ole32.CoUninitialize.restype  = None

ole32.CLSIDFromProgID.argtypes = (wintypes.LPCWSTR, ctypes.POINTER(GUID))
ole32.CLSIDFromProgID.restype  = HRESULT

ole32.CoCreateInstance.argtypes = (
    ctypes.POINTER(GUID),           # rclsid
    ctypes.c_void_p,                # pUnkOuter (aggregation) must be NULL
    wintypes.DWORD,                 # dwClsContext
    ctypes.POINTER(GUID),           # riid
    ctypes.POINTER(ctypes.c_void_p) # ppv
)
ole32.CoCreateInstance.restype = HRESULT

CLSCTX_INPROC_SERVER = 0x1
CLSCTX_LOCAL_SERVER  = 0x4
CLSCTX_ALL = CLSCTX_INPROC_SERVER | CLSCTX_LOCAL_SERVER

# ============================================================
# OLE Automation helpers: BSTR, VARIANT init/clear
# ============================================================
# BSTR allocation/free
oleaut32.SysAllocString.argtypes = (wintypes.LPCWSTR,)
oleaut32.SysAllocString.restype  = ctypes.c_void_p

# VariantInit / VariantClear are the safest way to manage VARIANT lifetime.
oleaut32.VariantInit.argtypes  = (ctypes.c_void_p,)  # (VARIANT*)
oleaut32.VariantInit.restype   = None
oleaut32.VariantClear.argtypes = (ctypes.c_void_p,)  # (VARIANT*)
oleaut32.VariantClear.restype  = HRESULT

# Optional: SysStringLen can help debugging BSTR length.
oleaut32.SysStringLen.argtypes = (ctypes.c_void_p,)  # (BSTR)
oleaut32.SysStringLen.restype  = wintypes.UINT

# ============================================================
# VARIANT (Windows-compatible layout)
# ============================================================
VT_EMPTY    = 0
VT_I4       = 3
VT_BSTR     = 8
VT_DISPATCH = 9

class VARIANT_UNION(ctypes.Union):
    _fields_ = [
        ("lVal",     wintypes.LONG),
        ("bstrVal",  ctypes.c_void_p),
        ("pdispVal", ctypes.c_void_p),
        ("punkVal",  ctypes.c_void_p),
        # Ensure the union is large enough for pointers on 64-bit.
        ("_ptr",     ctypes.c_void_p),
        # Force 16-byte union size on 64-bit (DECIMAL is 16 bytes in VARIANT).
        ("_decimal", ctypes.c_ubyte * 16),
    ]

class VARIANT(ctypes.Structure):
    _fields_ = [
        ("vt",         wintypes.USHORT),
        ("wReserved1", wintypes.USHORT),
        ("wReserved2", wintypes.USHORT),
        ("wReserved3", wintypes.USHORT),
        ("value",      VARIANT_UNION),
    ]

def variant_init(v: "VARIANT"):
    """Initialize VARIANT with VariantInit (sets VT_EMPTY and clears fields)."""
    oleaut32.VariantInit(ctypes.byref(v))

def variant_clear(v: "VARIANT"):
    """Clear VARIANT with VariantClear (frees BSTR, releases IDispatch, etc.)."""
    hr = oleaut32.VariantClear(ctypes.byref(v))
    if hr != 0:
        raise RuntimeError(f"VariantClear failed: 0x{hr & 0xFFFFFFFF:08X}")

def make_vt_i4(n: int) -> VARIANT:
    """Create a VT_I4 VARIANT."""
    v = VARIANT()
    variant_init(v)
    v.vt = VT_I4
    v.value.lVal = int(n)
    return v

def make_vt_bstr(s: str) -> VARIANT:
    """Create a VT_BSTR VARIANT. VariantClear will free it."""
    v = VARIANT()
    variant_init(v)
    v.vt = VT_BSTR
    v.value.bstrVal = oleaut32.SysAllocString(s)
    if not v.value.bstrVal:
        raise MemoryError("SysAllocString returned NULL.")
    return v

# ============================================================
# DISPPARAMS / EXCEPINFO for IDispatch::Invoke
# ============================================================
class DISPPARAMS(ctypes.Structure):
    _fields_ = [
        ("rgvarg", ctypes.POINTER(VARIANT)),           # VARIANTARG* (reversed order)
        ("rgdispidNamedArgs", ctypes.POINTER(DISPID)), # DISPID*
        ("cArgs", UINT),
        ("cNamedArgs", UINT),
    ]

class EXCEPINFO(ctypes.Structure):
    _fields_ = [
        ("wCode", wintypes.WORD),
        ("wReserved", wintypes.WORD),
        ("bstrSource", ctypes.c_void_p),
        ("bstrDescription", ctypes.c_void_p),
        ("bstrHelpFile", ctypes.c_void_p),
        ("dwHelpContext", wintypes.DWORD),
        ("pvReserved", ctypes.c_void_p),
        ("pfnDeferredFillIn", ctypes.c_void_p),
        ("scode", HRESULT),
    ]

# ============================================================
# IDispatch vtable (typed, safer than raw vtable indexing)
# ============================================================
QueryInterfaceProto = ctypes.WINFUNCTYPE(HRESULT, ctypes.c_void_p, ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p))
AddRefProto         = ctypes.WINFUNCTYPE(wintypes.ULONG, ctypes.c_void_p)
ReleaseProto        = ctypes.WINFUNCTYPE(wintypes.ULONG, ctypes.c_void_p)

GetTypeInfoCountProto = ctypes.WINFUNCTYPE(HRESULT, ctypes.c_void_p, ctypes.POINTER(UINT))
GetTypeInfoProto      = ctypes.WINFUNCTYPE(HRESULT, ctypes.c_void_p, UINT, LCID, ctypes.POINTER(ctypes.c_void_p))

# HRESULT GetIDsOfNames(
#   IDispatch* This,
#   REFIID riid,           (must be IID_NULL)
#   LPOLESTR* rgszNames,
#   UINT cNames,
#   LCID lcid,
#   DISPID* rgDispId
# )
GetIDsOfNamesProto = ctypes.WINFUNCTYPE(
    HRESULT,
    ctypes.c_void_p,
    ctypes.POINTER(GUID),
    ctypes.POINTER(wintypes.LPWSTR),
    UINT,
    LCID,
    ctypes.POINTER(DISPID)
)

# HRESULT Invoke(
#   IDispatch* This,
#   DISPID dispIdMember,
#   REFIID riid,           (must be IID_NULL)
#   LCID lcid,
#   WORD wFlags,
#   DISPPARAMS* pDispParams,
#   VARIANT* pVarResult,
#   EXCEPINFO* pExcepInfo,
#   UINT* puArgErr
# )
InvokeProto = ctypes.WINFUNCTYPE(
    HRESULT,
    ctypes.c_void_p,
    DISPID,
    ctypes.POINTER(GUID),
    LCID,
    WORD,
    ctypes.POINTER(DISPPARAMS),
    ctypes.POINTER(VARIANT),
    ctypes.POINTER(EXCEPINFO),
    ctypes.POINTER(UINT)
)

class IDispatchVtbl(ctypes.Structure):
    _fields_ = [
        ("QueryInterface",    QueryInterfaceProto),
        ("AddRef",            AddRefProto),
        ("Release",           ReleaseProto),
        ("GetTypeInfoCount",  GetTypeInfoCountProto),
        ("GetTypeInfo",       GetTypeInfoProto),
        ("GetIDsOfNames",     GetIDsOfNamesProto),
        ("Invoke",            InvokeProto),
    ]

class IDispatch(ctypes.Structure):
    _fields_ = [("lpVtbl", ctypes.POINTER(IDispatchVtbl))]

# Invoke flags
DISPATCH_METHOD = 0x1

# ============================================================
# Utility: release a COM interface pointer (IUnknown::Release)
# ============================================================
def release_unknown(p: ctypes.c_void_p):
    """Release a COM object pointer assumed to be IUnknown-compatible."""
    if p and p.value:
        disp = ctypes.cast(p, ctypes.POINTER(IDispatch))
        disp.contents.lpVtbl.contents.Release(p)

# ============================================================
# Main
# ============================================================
def main():
    hr = ole32.CoInitialize(None)
    if hr != 0:
        raise RuntimeError(f"CoInitialize failed: 0x{hr & 0xFFFFFFFF:08X}")

    pdisp_raw = ctypes.c_void_p()

    try:
        # Resolve ProgID -> CLSID
        clsid = GUID()
        hr = ole32.CLSIDFromProgID("Shell.Application", ctypes.byref(clsid))
        if hr != 0:
            raise RuntimeError(f"CLSIDFromProgID failed: 0x{hr & 0xFFFFFFFF:08X}")

        # Create COM object and request IDispatch*
        hr = ole32.CoCreateInstance(
            ctypes.byref(clsid),
            None,
            CLSCTX_ALL,
            ctypes.byref(IID_IDispatch),
            ctypes.byref(pdisp_raw),
        )
        if hr != 0 or not pdisp_raw.value:
            raise RuntimeError(f"CoCreateInstance failed: 0x{hr & 0xFFFFFFFF:08X}")

        pdisp = ctypes.cast(pdisp_raw, ctypes.POINTER(IDispatch))

        # ----------------------------------------------------
        # Get DISPID for method name "BrowseForFolder"
        # ----------------------------------------------------
        # Build a stable writable Unicode buffer for the name.
        name_buf = ctypes.create_unicode_buffer("BrowseForFolder")
        # Build LPOLESTR* array (LPWSTR*).
        names = (wintypes.LPWSTR * 1)(ctypes.cast(name_buf, wintypes.LPWSTR))

        dispid = DISPID()
        hr = pdisp.contents.lpVtbl.contents.GetIDsOfNames(
            pdisp_raw,
            ctypes.byref(IID_NULL),
            names,
            1,
            0,
            ctypes.byref(dispid)
        )
        if hr != 0:
            raise RuntimeError(f"GetIDsOfNames failed: 0x{hr & 0xFFFFFFFF:08X}")

        # ----------------------------------------------------
        # Invoke BrowseForFolder(hwnd, title, options, rootFolder)
        # IMPORTANT: Arguments are stored in reverse order in rgvarg.
        #   rgvarg[0] = rootFolder
        #   rgvarg[1] = options
        #   rgvarg[2] = title
        #   rgvarg[3] = hwnd
        # ----------------------------------------------------
        v_root  = make_vt_i4(36)
        v_opt   = make_vt_i4(0)
        v_title = make_vt_bstr("Hello, COM(Python) World!")
        v_hwnd  = make_vt_i4(0)

        # Debug: confirm VARIANT size and BSTR length are correct.
        print("sizeof(VARIANT)=", ctypes.sizeof(VARIANT))
        print("Title BSTR len:", oleaut32.SysStringLen(v_title.value.bstrVal))

        args = (VARIANT * 4)(v_root, v_opt, v_title, v_hwnd)

        dp = DISPPARAMS()
        dp.rgvarg = ctypes.cast(args, ctypes.POINTER(VARIANT))
        dp.rgdispidNamedArgs = None
        dp.cArgs = 4
        dp.cNamedArgs = 0

        result = VARIANT()
        variant_init(result)

        ex = EXCEPINFO()
        argerr = UINT(0)

        hr = pdisp.contents.lpVtbl.contents.Invoke(
            pdisp_raw,
            dispid,
            ctypes.byref(IID_NULL),
            0,
            DISPATCH_METHOD,
            ctypes.byref(dp),
            ctypes.byref(result),
            ctypes.byref(ex),
            ctypes.byref(argerr)
        )

        # Clear arguments (frees BSTR safely).
        # Note: Clearing VT_I4 is harmless; VariantClear expects initialized VARIANTs.
        variant_clear(v_title)
        variant_clear(v_root)
        variant_clear(v_opt)
        variant_clear(v_hwnd)

        if hr != 0:
            # If Invoke failed, EXCEPINFO may contain details, but parsing it is omitted here.
            raise RuntimeError(f"Invoke failed: 0x{hr & 0xFFFFFFFF:08X} (argerr={argerr.value})")

        # If successful, result often contains a Folder object as VT_DISPATCH.
        print(f"OK. result.vt={result.vt}, result.pdisp=0x{(result.value.pdispVal or 0):X}")

        # Clear result (VariantClear releases VT_DISPATCH automatically).
        variant_clear(result)

    finally:
        # Release Shell.Application IDispatch
        if pdisp_raw.value:
            release_unknown(pdisp_raw)

        ole32.CoUninitialize()

if __name__ == "__main__":
    main()
