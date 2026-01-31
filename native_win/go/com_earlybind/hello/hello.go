package main

import (
    "fmt"
    "runtime"
    "syscall"
    "unsafe"
)

// --- Constants ---
const (
    // VARIANT Types
    VT_I4 = 3 // 4-byte signed int

    // Shell Special Folder Constants
    ssfDESKTOP = 0x0000
    ssfDRIVES  = 0x0011
)

// --- DLL & Procs ---
var (
    ole32     = syscall.NewLazyDLL("ole32.dll")
    oleaut32  = syscall.NewLazyDLL("oleaut32.dll")
    shell32   = syscall.NewLazyDLL("shell32.dll") 

    procCoInitialize     = ole32.NewProc("CoInitialize")
    procCoUninitialize   = ole32.NewProc("CoUninitialize")
    procCoCreateInstance = ole32.NewProc("CoCreateInstance")
    procSysFreeString    = oleaut32.NewProc("SysFreeString")
)

// --- GUID Definitions ---
// CLSID_Shell: {13709620-C279-11CE-A49E-444553540000}
var CLSID_Shell = GUID{0x13709620, 0xC279, 0x11CE, [8]byte{0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}}

// IID_IShellDispatch: {D8F015C0-C278-11CE-A49E-444553540000}
var IID_IShellDispatch = GUID{0xD8F015C0, 0xC278, 0x11CE, [8]byte{0xA4, 0x9E, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00}}

// --- Struct Definitions ---

type GUID struct {
    Data1 uint32
    Data2 uint16
    Data3 uint16
    Data4 [8]byte
}

// VARIANT structure for Windows x64 (24 bytes)
// Actually a Union, but simplified here as we only use VT_I4(int).
type VARIANT struct {
    VT         uint16 // 0
    wReserved1 uint16 // 2
    wReserved2 uint16 // 4
    wReserved3 uint16 // 6
    Val        int64  // 8 (Reserve max size for Union & Alignment)
    _pad       int64  // 16 (Padding to reach total 24 bytes)
}

// --- Main ---

func main() {
    runtime.LockOSThread()
    
    // Initialize COM
    procCoInitialize.Call(0)
    defer procCoUninitialize.Call()

    fmt.Println("Creating Shell.Application instance via Early Binding...")

    var pUnknown uintptr
    hr, _, _ := procCoCreateInstance.Call(
        uintptr(unsafe.Pointer(&CLSID_Shell)),
        0,
        1, // CLSCTX_INPROC_SERVER
        uintptr(unsafe.Pointer(&IID_IShellDispatch)),
        uintptr(unsafe.Pointer(&pUnknown)),
    )
    if int32(hr) < 0 {
        fmt.Printf("Failed to create Shell instance. HRESULT: 0x%x\n", uint32(hr))
        return
    }
    defer comRelease(pUnknown)

    // Prepare arguments
    // 1. Title (BSTR/LPCWSTR)
    titleStr, _ := syscall.UTF16PtrFromString("Select a Folder (Go EarlyBind)")

    // 2. RootFolder (VARIANT)
    // Key point: In x64 ABI, large structures (like VARIANT) are passed by pointer (reference)
    // under the hood, even if the C definition looks like pass-by-value.
    // Specifying Desktop (0).
    var rootFolder VARIANT
    rootFolder.VT = VT_I4
    rootFolder.Val = 0 // ssfDESKTOP

    fmt.Println("Calling BrowseForFolder...")

    // IShellDispatch::BrowseForFolder call
    // VTable Index: 10
    // C++ Sig: Folder* BrowseForFolder(long Hwnd, BSTR Title, long Options, VARIANT RootFolder)
    var pFolder uintptr
    hr = comCall(pUnknown, 10,
        0,                                     // Hwnd
        uintptr(unsafe.Pointer(titleStr)),     // Title
        0,                                     // Options
        uintptr(unsafe.Pointer(&rootFolder)),  // RootFolder (Pointer to VARIANT structure)
        uintptr(unsafe.Pointer(&pFolder)),     // [out, retval] Folder**
    )

    // If user cancels, pFolder becomes NULL(0) even if HRESULT is S_OK(0).
    if pFolder == 0 {
        fmt.Println("User canceled.")
        return
    }
    defer comRelease(pFolder)

    fmt.Println("Folder selected. Retrieving path...")

    // Steps to retrieve path from Folder object:
    // Folder -> Folder.Self (gets FolderItem) -> FolderItem.Path

    // 1. Call Folder::get_Self
    // VTable Index: 17 (IDispatch(7) + 10th method)
    var pFolderItem uintptr
    hr = comCall(pFolder, 17, uintptr(unsafe.Pointer(&pFolderItem)))
    if int32(hr) < 0 || pFolderItem == 0 {
        fmt.Println("Failed to get FolderItem.")
        return
    }
    defer comRelease(pFolderItem)

    // 2. Call FolderItem::get_Path
    // VTable Index: 11 (IDispatch(7) + 4th method)
    var bstrPath uintptr
    hr = comCall(pFolderItem, 11, uintptr(unsafe.Pointer(&bstrPath)))
    if int32(hr) < 0 {
        fmt.Println("Failed to get Path.")
        return
    }

    // Convert BSTR to Go string
    path := bstrToString(bstrPath)
    fmt.Printf("Selected Path: %s\n", path)

    // Caller is responsible for freeing BSTR
    procSysFreeString.Call(bstrPath)
}

// --- Helper Functions ---

// Helper to call method via VTable
func comCall(obj uintptr, index int, args ...uintptr) uintptr {
    if obj == 0 {
        return 0
    }
    // obj is a pointer to *VTable.
    // *obj is the start address of VTable.
    vtable := *(*uintptr)(unsafe.Pointer(obj))
    // Get the function pointer at 'index' in VTable
    method := *(*uintptr)(unsafe.Pointer(vtable + uintptr(index)*8))

    // Create argument list: [0] is the 'this' pointer
    callArgs := make([]uintptr, len(args)+1)
    callArgs[0] = obj
    copy(callArgs[1:], args)

    ret, _, _ := syscall.SyscallN(method, callArgs...)
    return ret
}

func comRelease(obj uintptr) {
    if obj != 0 {
        // IUnknown::Release is Index 2
        comCall(obj, 2)
    }
}

// Convert BSTR (Windows wide string with length prefix) to Go string
func bstrToString(bstr uintptr) string {
    if bstr == 0 {
        return ""
    }
    // BSTR can be read as a simple UTF-16 pointer, though SysStringLen is the formal way to get length.
    // Here we simply convert from pointer.
    return syscall.UTF16ToString((*[1 << 30]uint16)(unsafe.Pointer(bstr))[:])
}
