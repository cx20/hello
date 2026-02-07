@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import platform.windows.*

// ============================================================
// COM Structures
// ============================================================

// GUID structure
class GUID(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(16, 4)
    
    var Data1: UInt
        get() = this.ptr.reinterpret<UIntVar>().pointed.value
        set(value) { this.ptr.reinterpret<UIntVar>().pointed.value = value }
    
    var Data2: UShort
        get() = interpretCPointer<UShortVar>(this.ptr.rawValue + 4)!!.pointed.value
        set(value) { interpretCPointer<UShortVar>(this.ptr.rawValue + 4)!!.pointed.value = value }
    
    var Data3: UShort
        get() = interpretCPointer<UShortVar>(this.ptr.rawValue + 6)!!.pointed.value
        set(value) { interpretCPointer<UShortVar>(this.ptr.rawValue + 6)!!.pointed.value = value }
    
    fun setData4(index: Int, value: UByte) {
        interpretCPointer<UByteVar>(this.ptr.rawValue + 8L + index.toLong())!!.pointed.value = value
    }
}

// VARIANT structure
class VARIANT(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(24, 8)
    
    var vt: UShort
        get() = this.ptr.reinterpret<UShortVar>().pointed.value
        set(value) { this.ptr.reinterpret<UShortVar>().pointed.value = value }
    
    var lVal: Int
        get() = interpretCPointer<IntVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<IntVar>(this.ptr.rawValue + 8)!!.pointed.value = value }
    
    var bstrVal: COpaquePointer?
        get() = interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value = value }
    
    var pdispVal: COpaquePointer?
        get() = interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value = value }
}

// DISPPARAMS structure
class DISPPARAMS(rawPtr: NativePtr) : CStructVar(rawPtr) {
    companion object : Type(32, 8)
    
    var rgvarg: CPointer<VARIANT>?
        get() = this.ptr.reinterpret<CPointerVar<VARIANT>>().pointed.value
        set(value) { this.ptr.reinterpret<CPointerVar<VARIANT>>().pointed.value = value }
    
    var rgdispidNamedArgs: COpaquePointer?
        get() = interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value
        set(value) { interpretCPointer<COpaquePointerVar>(this.ptr.rawValue + 8)!!.pointed.value = value }
    
    var cArgs: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 16)!!.pointed.value = value }
    
    var cNamedArgs: UInt
        get() = interpretCPointer<UIntVar>(this.ptr.rawValue + 20)!!.pointed.value
        set(value) { interpretCPointer<UIntVar>(this.ptr.rawValue + 20)!!.pointed.value = value }
}

// ============================================================
// Constants
// ============================================================

const val VT_I4: UShort = 3u
const val VT_BSTR: UShort = 8u
const val VT_DISPATCH: UShort = 9u
const val DISPATCH_METHOD: UShort = 1u
const val CLSCTX_INPROC_SERVER: UInt = 1u
const val ssfWINDOWS = 36

// ============================================================
// Helper Functions
// ============================================================

// Load oleaut32.dll functions
lateinit var sysAllocString: CPointer<CFunction<(CPointer<UShortVar>?) -> COpaquePointer?>>
lateinit var sysFreeString: CPointer<CFunction<(COpaquePointer?) -> Unit>>

fun initOleAut32() {
    val ole32 = LoadLibraryW("oleaut32.dll")!!
    sysAllocString = GetProcAddress(ole32, "SysAllocString")!!
        .reinterpret<CFunction<(CPointer<UShortVar>?) -> COpaquePointer?>>()
    sysFreeString = GetProcAddress(ole32, "SysFreeString")!!
        .reinterpret<CFunction<(COpaquePointer?) -> Unit>>()
}

// Initialize GUID with specified values
fun MemScope.initGUID(d1: UInt, d2: UShort, d3: UShort, d4: List<UByte>): CPointer<GUID> {
    val guid = alloc<GUID>()
    guid.Data1 = d1
    guid.Data2 = d2
    guid.Data3 = d3
    for (i in 0..7) {
        guid.setData4(i, d4[i])
    }
    return guid.ptr
}

// Call COM method via VTable
fun comMethod(obj: COpaquePointer, index: Int): COpaquePointer {
    val vtable = obj.reinterpret<COpaquePointerVar>().pointed.value!!.reinterpret<COpaquePointerVar>()
    return vtable[index]!!
}

// ============================================================
// Main Function
// ============================================================

fun main() = memScoped {
    println("COM Late Binding Sample - Shell.Application BrowseForFolder")
    println("=============================================================")
    
    // Initialize OLE Automation
    initOleAut32()
    
    // Initialize COM
    CoInitialize(null)
    
    // IID_IDispatch {00020400-0000-0000-C000-000000000046}
    val IID_IDispatch = initGUID(0x00020400u, 0x0000u, 0x0000u,
        listOf(0xC0u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x46u))
    
    // IID_NULL (all zeros)
    val IID_NULL = initGUID(0u, 0u, 0u,
        listOf(0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u))
    
    // CLSID from ProgID
    val clsid = alloc<GUID>()
    val hr1 = CLSIDFromProgID("Shell.Application".wcstr.ptr, clsid.ptr.reinterpret())
    if (hr1 != 0) {
        println("CLSIDFromProgID failed: 0x${hr1.toString(16)}")
        CoUninitialize()
        return@memScoped
    }
    println("CLSIDFromProgID succeeded")
    
    // Create COM instance
    val pShell = allocArray<COpaquePointerVar>(1)
    val hr2 = CoCreateInstance(clsid.ptr.reinterpret(), null, CLSCTX_INPROC_SERVER,
        IID_IDispatch.reinterpret(), pShell.reinterpret())
    if (hr2 != 0) {
        println("CoCreateInstance failed: 0x${hr2.toString(16)}")
        CoUninitialize()
        return@memScoped
    }
    println("CoCreateInstance succeeded")
    
    val pDisp = pShell[0]!!
    
    // Get DISPID for "BrowseForFolder"
    val methodName = allocArray<CPointerVar<UShortVar>>(1)
    methodName[0] = "BrowseForFolder".wcstr.ptr
    val dispid = alloc<IntVar>()
    
    val getIDsOfNamesPtr = comMethod(pDisp, 5)
    val getIDsOfNames = getIDsOfNamesPtr.reinterpret<CFunction<(COpaquePointer?, CPointer<GUID>?, CPointer<CPointerVar<UShortVar>>?,
        UInt, UInt, CPointer<IntVar>?) -> Int>>()
    
    val hr3 = getIDsOfNames.invoke(pDisp, IID_NULL, methodName, 1u, 0u, dispid.ptr)
    if (hr3 != 0) {
        println("GetIDsOfNames failed: 0x${hr3.toString(16)}")
        val releasePtrErr = comMethod(pDisp, 2)
        val releaseErr = releasePtrErr.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
        releaseErr.invoke(pDisp)
        CoUninitialize()
        return@memScoped
    }
    println("GetIDsOfNames succeeded, DISPID=${dispid.value}")
    
    // Prepare arguments (in reverse order)
    // BrowseForFolder(hwnd, title, options, rootFolder)
    val varg = allocArray<VARIANT>(4)
    
    // varg[0] = rootFolder (VT_I4 = ssfWINDOWS)
    varg[0].vt = VT_I4
    varg[0].lVal = ssfWINDOWS
    
    // varg[1] = options (VT_I4 = 0)
    varg[1].vt = VT_I4
    varg[1].lVal = 0
    
    // varg[2] = title (VT_BSTR)
    varg[2].vt = VT_BSTR
    varg[2].bstrVal = sysAllocString("Hello, COM(Kotlin/Native) World!".wcstr.ptr)
    
    // varg[3] = hwnd (VT_I4 = 0)
    varg[3].vt = VT_I4
    varg[3].lVal = 0
    
    // DISPPARAMS
    val dp = alloc<DISPPARAMS>()
    dp.rgvarg = varg
    dp.rgdispidNamedArgs = null
    dp.cArgs = 4u
    dp.cNamedArgs = 0u
    
    // Call Invoke
    val pVarResult = alloc<VARIANT>()
    pVarResult.vt = 0u // VT_EMPTY
    
    val invokePtr = comMethod(pDisp, 6)
    val invoke = invokePtr.reinterpret<CFunction<(COpaquePointer?, Int, CPointer<GUID>?, UInt, UShort,
        CPointer<DISPPARAMS>?, CPointer<VARIANT>?, COpaquePointer?, CPointer<UIntVar>?) -> Int>>()
    
    println("Calling BrowseForFolder...")
    val hr4 = invoke.invoke(pDisp, dispid.value, IID_NULL, 0u, DISPATCH_METHOD,
        dp.ptr, pVarResult.ptr, null, null)
    
    if (hr4 != 0) {
        println("Invoke failed: 0x${hr4.toString(16)}")
    } else {
        println("BrowseForFolder succeeded!")
        
        // If result is IDispatch, release it
        if (pVarResult.vt == VT_DISPATCH) {
            val pResultDisp = pVarResult.pdispVal
            if (pResultDisp != null) {
                val releasePtr = comMethod(pResultDisp, 2)
                val release = releasePtr.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
                release.invoke(pResultDisp)
            }
        }
    }
    
    // Free BSTR
    sysFreeString(varg[2].bstrVal)
    
    // Release IDispatch
    val releasePtr = comMethod(pDisp, 2)
    val release = releasePtr.reinterpret<CFunction<(COpaquePointer?) -> UInt>>()
    release.invoke(pDisp)
    
    // Uninitialize COM
    CoUninitialize()
    
    println("Done.")
}
