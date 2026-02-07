@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// ---- GUID structure definition ----
class GUID(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var Data1: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Data2: UShort
        get() = this.ptr.rawValue.plus(4).toLong().toCPointer<UShortVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(4).toLong().toCPointer<UShortVar>()!!.pointed.value = value }
    
    var Data3: UShort
        get() = this.ptr.rawValue.plus(6).toLong().toCPointer<UShortVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(6).toLong().toCPointer<UShortVar>()!!.pointed.value = value }
    
    fun setData4(index: Int, value: UByte) {
        this.ptr.rawValue.plus(8L + index).toLong().toCPointer<UByteVar>()!!.pointed.value = value
    }
    
    fun getData4(index: Int): UByte {
        return this.ptr.rawValue.plus(8L + index).toLong().toCPointer<UByteVar>()!!.pointed.value
    }
}

// ---- VARIANT structure ----
class VARIANT(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 8)
    
    var vt: UShort
        get() = this.ptr.reinterpret<UShortVar>().pointed.value
        set(value) { this.ptr.reinterpret<UShortVar>().pointed.value = value }
    
    var lVal: Int
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<IntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<IntVar>()!!.pointed.value = value }
    
    var bstrVal: COpaquePointer?
        get() = this.ptr.rawValue.plus(8).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(8).toLong().toCPointer<COpaquePointerVar>()!!.pointed.value = value }
}

// ---- DISPPARAMS structure ----
class DISPPARAMS(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 8)
    
    var rgvarg: CPointer<VARIANT>?
        get() = this.ptr.reinterpret<CPointerVar<VARIANT>>().pointed.value
        set(value) { this.ptr.reinterpret<CPointerVar<VARIANT>>().pointed.value = value }
    
    var cArgs: UInt
        get() = this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value
        set(value) { this.ptr.rawValue.plus(16).toLong().toCPointer<UIntVar>()!!.pointed.value = value }
}

// ---- EXCEPINFO structure (simplified) ----
class EXCEPINFO(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 8)
}

// ---- OLE Automation dynamic loading ----
private var oleaut32Handle: CPointer<HINSTANCE__>? = null
private var sysAllocStringFunc: CPointer<CFunction<(CPointer<UShortVar>?) -> COpaquePointer?>>? = null
private var sysFreeStringFunc: CPointer<CFunction<(COpaquePointer?) -> Unit>>? = null

private fun initOleAutomation() {
    oleaut32Handle = LoadLibraryW("oleaut32.dll")
    if (oleaut32Handle == null) {
        println("[ERROR] Failed to load oleaut32.dll")
        return
    }
    
    sysAllocStringFunc = GetProcAddress(oleaut32Handle, "SysAllocString")
        ?.reinterpret<CFunction<(CPointer<UShortVar>?) -> COpaquePointer?>>()
    
    sysFreeStringFunc = GetProcAddress(oleaut32Handle, "SysFreeString")
        ?.reinterpret<CFunction<(COpaquePointer?) -> Unit>>()
}

private fun SysAllocString(psz: CPointer<UShortVar>?): COpaquePointer? {
    return sysAllocStringFunc?.invoke(psz)
}

private fun SysFreeString(bstrString: COpaquePointer?) {
    sysFreeStringFunc?.invoke(bstrString)
}

private fun VariantInit(pvarg: CPointer<VARIANT>?) {
    // VariantInit just sets vt to VT_EMPTY (0)
    pvarg?.pointed?.vt = 0u
}

private fun VariantClear(pvarg: CPointer<VARIANT>?): Int {
    if (pvarg == null) return 0
    
    val variant = pvarg.pointed
    // If it's a BSTR, free it
    if (variant.vt.toInt() == 8) { // VT_BSTR
        SysFreeString(variant.bstrVal)
    }
    variant.vt = 0u // VT_EMPTY
    return 0
}

// VT constants
private const val VT_I4: UShort = 3u
private const val VT_BSTR: UShort = 8u

// DISPATCH constants  
private const val DISPATCH_METHOD: UShort = 1u

// Special folder constants
private const val ssfWINDOWS = 36

// CLSID for Shell.Application: {13709620-C279-11CE-A49E-444553540000}
private fun MemScope.createCLSID_Shell(): CPointer<GUID> {
    val guid = alloc<GUID>()
    guid.Data1 = 0x13709620u
    guid.Data2 = 0xC279u
    guid.Data3 = 0x11CEu
    guid.setData4(0, 0xA4u)
    guid.setData4(1, 0x9Eu)
    guid.setData4(2, 0x44u)
    guid.setData4(3, 0x45u)
    guid.setData4(4, 0x53u)
    guid.setData4(5, 0x54u)
    guid.setData4(6, 0x00u)
    guid.setData4(7, 0x00u)
    return guid.ptr
}

// IID_IDispatch: {00020400-0000-0000-C000-000000000046}
private fun MemScope.createIID_IDispatch(): CPointer<GUID> {
    val guid = alloc<GUID>()
    guid.Data1 = 0x00020400u
    guid.Data2 = 0x0000u
    guid.Data3 = 0x0000u
    guid.setData4(0, 0xC0u)
    guid.setData4(1, 0x00u)
    guid.setData4(2, 0x00u)
    guid.setData4(3, 0x00u)
    guid.setData4(4, 0x00u)
    guid.setData4(5, 0x00u)
    guid.setData4(6, 0x00u)
    guid.setData4(7, 0x46u)
    return guid.ptr
}

// IID_NULL (all zeros)
private fun MemScope.createIID_NULL(): CPointer<GUID> {
    val guid = alloc<GUID>()
    guid.Data1 = 0u
    guid.Data2 = 0u
    guid.Data3 = 0u
    for (i in 0..7) {
        guid.setData4(i, 0u)
    }
    return guid.ptr
}

fun main() {
    memScoped {
        println("[main] Starting Kotlin/Native COM early binding (BrowseForFolder) example...")
        
        // Initialize OLE Automation functions
        initOleAutomation()
        
        // Initialize COM library
        val hInitResult = CoInitialize(null)
        if (hInitResult != 0) {
            println("[main] ERROR: CoInitialize failed with HRESULT: 0x${hInitResult.toString(16)}")
            return@memScoped
        }
        println("[main] CoInitialize succeeded")
        
        try {
            // Create GUIDs
            val clsidShell = createCLSID_Shell()
            val iidDispatch = createIID_IDispatch()
            val iidNull = createIID_NULL()
            
            // Create Shell.Application COM object
            val ppv = allocArray<COpaquePointerVar>(1)
            
            val hCreateResult = CoCreateInstance(
                clsidShell.reinterpret(),
                null,
                1u, // CLSCTX_INPROC_SERVER
                iidDispatch.reinterpret(),
                ppv.reinterpret()
            )
            
            if (hCreateResult != 0) {
                println("[main] ERROR: CoCreateInstance failed with HRESULT: 0x${hCreateResult.toString(16)}")
                return@memScoped
            }
            println("[main] CoCreateInstance succeeded")
            
            val pDisp = ppv[0]
            if (pDisp == null) {
                println("[main] ERROR: pDisp is null after CoCreateInstance")
                return@memScoped
            }
            
            println("[main] Successfully created Shell.Application IDispatch object")
            
            // Get IDispatch VTable
            // VTable: [0]=QueryInterface, [1]=AddRef, [2]=Release, [3]=GetTypeInfoCount, 
            //         [4]=GetTypeInfo, [5]=GetIDsOfNames, [6]=Invoke
            val pVtbl = pDisp.reinterpret<COpaquePointerVar>().pointed.value
            if (pVtbl == null) {
                println("[main] ERROR: VTable pointer is null")
                return@memScoped
            }
            
            val vtableArray = pVtbl.reinterpret<COpaquePointerVar>()
            
            // Get DISPID for "BrowseForFolder"
            val methodName = "BrowseForFolder"
            val nameBuf = methodName.wcstr.ptr
            val names = allocArray<CPointerVar<UShortVar>>(1)
            names[0] = nameBuf
            
            val dispid = alloc<IntVar>()
            
            val pGetIDsOfNames = vtableArray[5]
            if (pGetIDsOfNames == null) {
                println("[main] ERROR: GetIDsOfNames method pointer is null")
                return@memScoped
            }
            
            // GetIDsOfNames signature:
            // HRESULT GetIDsOfNames(IDispatch* this, REFIID riid, LPOLESTR* rgszNames, UINT cNames, LCID lcid, DISPID* rgDispId)
            val getIDsOfNames = pGetIDsOfNames.reinterpret<CFunction<(COpaquePointer?, CPointer<GUID>?, CPointer<CPointerVar<UShortVar>>?, UInt, UInt, CPointer<IntVar>?) -> Int>>()
            
            val hrGetIds = getIDsOfNames(pDisp, iidNull, names, 1u, 0u, dispid.ptr)
            if (hrGetIds != 0) {
                println("[main] ERROR: GetIDsOfNames failed with HRESULT: 0x${hrGetIds.toString(16)}")
                return@memScoped
            }
            println("[main] Got DISPID for BrowseForFolder: ${dispid.value}")
            
            // Prepare VARIANT arguments (in REVERSE order!)
            // BrowseForFolder(hwnd, title, options, rootFolder)
            // args[0] = rootFolder, args[1] = options, args[2] = title, args[3] = hwnd
            
            val args = allocArray<VARIANT>(4)
            
            // args[0] = rootFolder (VT_I4 = ssfWINDOWS = 36)
            VariantInit(args[0].ptr)
            args[0].vt = VT_I4
            args[0].lVal = ssfWINDOWS
            
            // args[1] = options (VT_I4 = 0)
            VariantInit(args[1].ptr)
            args[1].vt = VT_I4
            args[1].lVal = 0
            
            // args[2] = title (VT_BSTR)
            VariantInit(args[2].ptr)
            args[2].vt = VT_BSTR
            val titleBstr = SysAllocString("Hello, COM(Kotlin/Native) World!".wcstr.ptr)
            args[2].bstrVal = titleBstr
            
            // args[3] = hwnd (VT_I4 = 0)
            VariantInit(args[3].ptr)
            args[3].vt = VT_I4
            args[3].lVal = 0
            
            // Prepare DISPPARAMS
            val dp = alloc<DISPPARAMS>()
            dp.rgvarg = args
            dp.cArgs = 4u
            
            // Prepare result VARIANT
            val result = alloc<VARIANT>()
            VariantInit(result.ptr)
            
            // Prepare EXCEPINFO
            val excepInfo = alloc<EXCEPINFO>()
            
            // Call Invoke
            val pInvoke = vtableArray[6]
            if (pInvoke == null) {
                println("[main] ERROR: Invoke method pointer is null")
                return@memScoped
            }
            
            // Invoke signature:
            // HRESULT Invoke(IDispatch* this, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, 
            //                DISPPARAMS* pDispParams, VARIANT* pVarResult, EXCEPINFO* pExcepInfo, UINT* puArgErr)
            val invoke = pInvoke.reinterpret<CFunction<(COpaquePointer?, Int, CPointer<GUID>?, UInt, UShort, CPointer<DISPPARAMS>?, CPointer<VARIANT>?, CPointer<EXCEPINFO>?, CPointer<UIntVar>?) -> Int>>()
            
            println("[main] Calling BrowseForFolder via Invoke...")
            val hrInvoke = invoke(pDisp, dispid.value, iidNull, 0u, DISPATCH_METHOD, dp.ptr, result.ptr, excepInfo.ptr, null)
            
            if (hrInvoke != 0) {
                println("[main] ERROR: Invoke failed with HRESULT: 0x${hrInvoke.toString(16)}")
            } else {
                println("[main] BrowseForFolder succeeded! result.vt=${result.vt}")
            }
            
            // Clean up VARIANTs
            VariantClear(args[2].ptr) // Frees BSTR
            VariantClear(result.ptr)
            
            // Release IDispatch
            val pRelease = vtableArray[2]
            if (pRelease != null) {
                println("[main] Calling Release method...")
                val releaseFunc = pRelease.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
                val refCount = releaseFunc(pDisp)
                println("[main] Release called, remaining ref count: $refCount")
            }
            
        } finally {
            // Uninitialize COM library
            CoUninitialize()
            println("[main] CoUninitialize completed")
        }
        
        println("[main] Example finished successfully")
    }
}
