// hello.go - WinUI3 XAML Island Triangle Sample using Go
//
// Draws a gradient-filled triangle via WinUI3 XAML DesktopWindowXamlSource
// using raw COM vtable calls through syscall. No CGO or external helper
// DLL required. MddBootstrapInitialize2 is called directly with version
// constants defined in Go.

package main

import (
	"fmt"
	"runtime"
	"syscall"
	"unsafe"
)

// =====================================================================
// Windows type definitions
// =====================================================================

type GUID struct {
	Data1 uint32
	Data2 uint16
	Data3 uint16
	Data4 [8]byte
}

type POINT struct {
	X, Y int32
}

type RECT struct {
	Left, Top, Right, Bottom int32
}

type MSG struct {
	Hwnd    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      POINT
}

type WNDCLASSEXW struct {
	Size       uint32
	Style      uint32
	WndProc    uintptr
	ClsExtra   int32
	WndExtra   int32
	Instance   uintptr
	Icon       uintptr
	Cursor     uintptr
	Background uintptr
	MenuName   *uint16
	ClassName  *uint16
	IconSm     uintptr
}

// DispatcherQueue types for CoreMessaging fallback
type DispatcherQueueOptions struct {
	DwSize        uint32
	ThreadType    uint32
	ApartmentType uint32
}

type WindowId struct {
	Value uint64
}

// =====================================================================
// Constants
// =====================================================================

const (
	WS_OVERLAPPEDWINDOW = 0x00CF0000
	WM_DESTROY          = 0x0002
	CW_USEDEFAULT       = 0x80000000
	SW_SHOW             = 5
	CS_HREDRAW          = 0x0002
	CS_VREDRAW          = 0x0001
	COLOR_WINDOW        = 5
	IDC_ARROW           = 32512
	MB_ICONERROR        = 0x00000010
	MB_OK               = 0x00000000
	COINIT_APARTMENTTHREADED = 0x2
	RO_INIT_SINGLETHREADED  = 0
	DQTYPE_THREAD_CURRENT    = 2
	DQTAT_COM_NONE           = 0
)

// COM vtable method indices
const (
	vtQueryInterface = 0
	vtAddRef         = 1
	vtRelease        = 2
	// IInspectable: 3=GetIids, 4=GetRuntimeClassName, 5=GetTrustLevel
	// Interface-specific methods start at index 6
)

const ptrSize = unsafe.Sizeof(uintptr(0))

// =====================================================================
// Interface GUIDs
// =====================================================================

var (
	IID_IWindowsXamlManagerStatics = GUID{
		0x56CB591D, 0xDE97, 0x539F,
		[8]byte{0x88, 0x1D, 0x8C, 0xCD, 0xC4, 0x4F, 0xA6, 0xC4}}
	IID_IDesktopWindowXamlSource = GUID{
		0x553AF92C, 0x1381, 0x51D6,
		[8]byte{0xBE, 0xE0, 0xF3, 0x4B, 0xEB, 0x04, 0x2E, 0xA8}}
	IID_IXamlReaderStatics = GUID{
		0x82A4CD9E, 0x435E, 0x5AEB,
		[8]byte{0x8C, 0x4F, 0x30, 0x0C, 0xEC, 0xE4, 0x5C, 0xAE}}
	IID_IUIElement = GUID{
		0xC3C01020, 0x320C, 0x5CF6,
		[8]byte{0x9D, 0x24, 0xD3, 0x96, 0xBB, 0xFA, 0x4D, 0x8B}}
	IID_IDispatcherQueueControllerStatics = GUID{
		0xF18D6145, 0x722B, 0x593D,
		[8]byte{0xBC, 0xF2, 0xA6, 0x1E, 0x71, 0x3F, 0x00, 0x37}}
)

// =====================================================================
// DLL and procedure declarations
// =====================================================================

var (
	user32   = syscall.NewLazyDLL("user32.dll")
	kernel32 = syscall.NewLazyDLL("kernel32.dll")
	ole32    = syscall.NewLazyDLL("ole32.dll")
	combase  = syscall.NewLazyDLL("combase.dll")
	coreMsg      = syscall.NewLazyDLL("CoreMessaging.dll")
	bootstrapDLL = syscall.NewLazyDLL("Microsoft.WindowsAppRuntime.Bootstrap.dll")

	// user32
	procRegisterClassExW = user32.NewProc("RegisterClassExW")
	procCreateWindowExW  = user32.NewProc("CreateWindowExW")
	procDefWindowProcW   = user32.NewProc("DefWindowProcW")
	procShowWindow       = user32.NewProc("ShowWindow")
	procUpdateWindow     = user32.NewProc("UpdateWindow")
	procGetMessageW      = user32.NewProc("GetMessageW")
	procTranslateMessage = user32.NewProc("TranslateMessage")
	procDispatchMessageW = user32.NewProc("DispatchMessageW")
	procPostQuitMessage  = user32.NewProc("PostQuitMessage")
	procLoadCursorW      = user32.NewProc("LoadCursorW")
	procAdjustWindowRect = user32.NewProc("AdjustWindowRect")
	procMessageBoxW      = user32.NewProc("MessageBoxW")

	// kernel32
	procGetModuleHandleW  = kernel32.NewProc("GetModuleHandleW")
	procLoadLibraryW      = kernel32.NewProc("LoadLibraryW")
	procGetProcAddress    = kernel32.NewProc("GetProcAddress")
	procOutputDebugStringA = kernel32.NewProc("OutputDebugStringA")

	// ole32
	procCoInitializeEx = ole32.NewProc("CoInitializeEx")
	procCoUninitialize = ole32.NewProc("CoUninitialize")

	// combase (WinRT)
	procRoInitialize           = combase.NewProc("RoInitialize")
	procRoUninitialize         = combase.NewProc("RoUninitialize")
	procRoGetActivationFactory = combase.NewProc("RoGetActivationFactory")
	procRoActivateInstance     = combase.NewProc("RoActivateInstance")
	procWindowsCreateString    = combase.NewProc("WindowsCreateString")
	procWindowsDeleteString    = combase.NewProc("WindowsDeleteString")

	// CoreMessaging
	procCreateDispatcherQueueController = coreMsg.NewProc("CreateDispatcherQueueController")

	// Microsoft.WindowsAppRuntime.Bootstrap.dll
	procMddBootstrapInitialize2 = bootstrapDLL.NewProc("MddBootstrapInitialize2")
	procMddBootstrapShutdown    = bootstrapDLL.NewProc("MddBootstrapShutdown")
)

// =====================================================================
// Windows App SDK version constants
// =====================================================================
//
// These constants correspond to the macros defined in
// WindowsAppSDK-VersionInfo.h. Update them when changing the SDK version.
//
// To find the correct values, open:
//   %USERPROFILE%\.nuget\packages\microsoft.windowsappsdk.runtime\<ver>\include\WindowsAppSDK-VersionInfo.h
//   %USERPROFILE%\.nuget\packages\microsoft.windowsappsdk.foundation\<ver>\include\MddBootstrap.h
//
// WINDOWSAPPSDK_RELEASE_MAJORMINOR is (major << 16 | minor).
// WINDOWSAPPSDK_RELEASE_VERSION_TAG_W is L"" for stable releases,
//   L"-preview" for preview, etc.
// WINDOWSAPPSDK_RUNTIME_VERSION_UINT64 is the packed PACKAGE_VERSION:
//   (major << 48 | minor << 32 | build << 16 | revision).
//   Passing 0 means "accept any runtime version for this major.minor".

const (
	windowsAppSDKReleaseMajorMinor      = 0x00010008 // 1.8
	windowsAppSDKReleaseVersionTag      = ""         // stable
	windowsAppSDKRuntimeVersionUint64   = 0          // 0 = any runtime version
	mddBootstrapInitializeOptions_None  = 0
)

// mddBootstrapInit calls MddBootstrapInitialize2 directly.
func mddBootstrapInit() int32 {
	tagPtr, _ := syscall.UTF16PtrFromString(windowsAppSDKReleaseVersionTag)
	hr, _, _ := procMddBootstrapInitialize2.Call(
		uintptr(windowsAppSDKReleaseMajorMinor),
		uintptr(unsafe.Pointer(tagPtr)),
		uintptr(windowsAppSDKRuntimeVersionUint64),
		uintptr(mddBootstrapInitializeOptions_None))
	return int32(hr)
}

// mddBootstrapDeinit calls MddBootstrapShutdown.
func mddBootstrapDeinit() {
	procMddBootstrapShutdown.Call()
}

// =====================================================================
// Global state
// =====================================================================

var (
	gMainWindow                        uintptr
	gDispatcherQueueController         uintptr // IInspectable*
	gCoreDispatcherQueueController     uintptr // IUnknown*
	gWindowsXamlManager                uintptr // IInspectable*
	gDesktopWindowXamlSourceInspectable uintptr // IInspectable*
	gDesktopWindowXamlSource           uintptr // IDesktopWindowXamlSource*
)

// =====================================================================
// Utility functions
// =====================================================================

func logState(fn, format string, args ...interface{}) {
	msg := fmt.Sprintf("[%s] %s\n", fn, fmt.Sprintf(format, args...))
	p, _ := syscall.BytePtrFromString(msg)
	procOutputDebugStringA.Call(uintptr(unsafe.Pointer(p)))
}

// comCall invokes a COM vtable method at the given index.
// obj is a pointer to the COM interface. Additional args follow.
func comCall(obj uintptr, vtblIdx uintptr, args ...uintptr) uintptr {
	vtbl := *(*uintptr)(unsafe.Pointer(obj))
	method := *(*uintptr)(unsafe.Pointer(vtbl + vtblIdx*ptrSize))
	n := uintptr(1 + len(args))
	switch len(args) {
	case 0:
		r, _, _ := syscall.Syscall(method, n, obj, 0, 0)
		return r
	case 1:
		r, _, _ := syscall.Syscall(method, n, obj, args[0], 0)
		return r
	case 2:
		r, _, _ := syscall.Syscall(method, n, obj, args[0], args[1])
		return r
	case 3:
		r, _, _ := syscall.Syscall6(method, n, obj, args[0], args[1], args[2], 0, 0)
		return r
	default:
		return 0
	}
}

func comRelease(obj uintptr) {
	if obj != 0 {
		comCall(obj, vtRelease)
	}
}

func comQueryInterface(obj uintptr, iid *GUID, out *uintptr) int32 {
	return int32(comCall(obj, vtQueryInterface,
		uintptr(unsafe.Pointer(iid)),
		uintptr(unsafe.Pointer(out))))
}

func releaseIf(pp *uintptr) {
	if *pp != 0 {
		comRelease(*pp)
		*pp = 0
	}
}

// createHString creates an HSTRING from a Go string.
// Caller must call deleteHString when done.
func createHString(s string) (uintptr, error) {
	utf16, err := syscall.UTF16FromString(s)
	if err != nil {
		return 0, err
	}
	var hstring uintptr
	hr, _, _ := procWindowsCreateString.Call(
		uintptr(unsafe.Pointer(&utf16[0])),
		uintptr(len(utf16)-1), // exclude null terminator
		uintptr(unsafe.Pointer(&hstring)))
	if int32(hr) < 0 {
		return 0, fmt.Errorf("WindowsCreateString failed: 0x%08X", uint32(hr))
	}
	return hstring, nil
}

func deleteHString(hs uintptr) {
	if hs != 0 {
		procWindowsDeleteString.Call(hs)
	}
}

// =====================================================================
// DispatcherQueue initialization
// =====================================================================

func ensureDispatcherQueue() int32 {
	const fn = "ensureDispatcherQueue"

	if gDispatcherQueueController != 0 && gCoreDispatcherQueueController != 0 {
		logState(fn, "already initialized")
		return 0 // S_OK
	}

	// Try WinUI3 DispatcherQueueController.CreateOnCurrentThread
	if gDispatcherQueueController == 0 {
		className, err := createHString("Microsoft.UI.Dispatching.DispatcherQueueController")
		if err == nil {
			var statics uintptr
			hr, _, _ := procRoGetActivationFactory.Call(
				className,
				uintptr(unsafe.Pointer(&IID_IDispatcherQueueControllerStatics)),
				uintptr(unsafe.Pointer(&statics)))
			logState(fn, "RoGetActivationFactory(DispatcherQueueController) hr=0x%08X", uint32(hr))
			if int32(hr) >= 0 && statics != 0 {
				// CreateOnCurrentThread is at vtable index 7
				r := comCall(statics, 7, uintptr(unsafe.Pointer(&gDispatcherQueueController)))
				logState(fn, "CreateOnCurrentThread hr=0x%08X controller=0x%X",
					uint32(r), gDispatcherQueueController)
			}
			releaseIf(&statics)
			deleteHString(className)
		}
	}

	// Fallback to CoreMessaging
	if gCoreDispatcherQueueController == 0 {
		options := DispatcherQueueOptions{
			DwSize:        uint32(unsafe.Sizeof(DispatcherQueueOptions{})),
			ThreadType:    DQTYPE_THREAD_CURRENT,
			ApartmentType: DQTAT_COM_NONE,
		}
		hrCore, _, _ := procCreateDispatcherQueueController.Call(
			uintptr(unsafe.Pointer(&options)),
			uintptr(unsafe.Pointer(&gCoreDispatcherQueueController)))
		logState(fn, "CoreMessaging CreateDispatcherQueueController hr=0x%08X controller=0x%X",
			uint32(hrCore), gCoreDispatcherQueueController)
	}

	if gDispatcherQueueController != 0 || gCoreDispatcherQueueController != 0 {
		return 0 // S_OK
	}
	return -1
}

// =====================================================================
// WindowId resolution
// =====================================================================

func getWindowIdForHwnd(hwnd uintptr) (WindowId, int32) {
	const fn = "getWindowIdForHwnd"
	var windowId WindowId

	// Load Microsoft.Internal.FrameworkUdk.dll
	dllName, _ := syscall.UTF16PtrFromString("Microsoft.Internal.FrameworkUdk.dll")
	mod, _, _ := procGetModuleHandleW.Call(uintptr(unsafe.Pointer(dllName)))
	if mod == 0 {
		mod, _, _ = procLoadLibraryW.Call(uintptr(unsafe.Pointer(dllName)))
	}
	if mod == 0 {
		logState(fn, "LoadLibraryW failed")
		return windowId, -1
	}

	procName, _ := syscall.BytePtrFromString("Windowing_GetWindowIdFromWindow")
	proc, _, _ := procGetProcAddress.Call(mod, uintptr(unsafe.Pointer(procName)))
	if proc == 0 {
		logState(fn, "GetProcAddress failed")
		return windowId, -1
	}

	hr, _, _ := syscall.Syscall(proc, 2,
		hwnd,
		uintptr(unsafe.Pointer(&windowId)),
		0)
	logState(fn, "Windowing_GetWindowIdFromWindow hr=0x%08X value=%d",
		uint32(hr), windowId.Value)
	return windowId, int32(hr)
}

// =====================================================================
// XAML content loading
// =====================================================================

func loadTriangleXaml() int32 {
	const fn = "loadTriangleXaml"

	// Triangle XAML markup
	const triangleXaml = `<Canvas xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' ` +
		`xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Background='White'>` +
		`<Path Stroke='Black' StrokeThickness='1'>` +
		`<Path.Fill>` +
		`<LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>` +
		`<GradientStop Color='Red' Offset='0'/>` +
		`<GradientStop Color='Green' Offset='0.5'/>` +
		`<GradientStop Color='Blue' Offset='1'/>` +
		`</LinearGradientBrush>` +
		`</Path.Fill>` +
		`<Path.Data>` +
		`<PathGeometry>` +
		`<PathFigure StartPoint='300,100' IsClosed='True'>` +
		`<LineSegment Point='500,400'/>` +
		`<LineSegment Point='100,400'/>` +
		`</PathFigure>` +
		`</PathGeometry>` +
		`</Path.Data>` +
		`</Path>` +
		`</Canvas>`

	// Get XamlReader activation factory
	className, err := createHString("Microsoft.UI.Xaml.Markup.XamlReader")
	if err != nil {
		logState(fn, "createHString(class) failed: %v", err)
		return -1
	}
	defer deleteHString(className)

	var xamlReaderStatics uintptr
	hr, _, _ := procRoGetActivationFactory.Call(
		className,
		uintptr(unsafe.Pointer(&IID_IXamlReaderStatics)),
		uintptr(unsafe.Pointer(&xamlReaderStatics)))
	logState(fn, "RoGetActivationFactory(XamlReader) hr=0x%08X", uint32(hr))
	if int32(hr) < 0 {
		return int32(hr)
	}
	defer releaseIf(&xamlReaderStatics)

	// Create HSTRING for XAML text
	xamlText, err := createHString(triangleXaml)
	if err != nil {
		logState(fn, "createHString(xaml) failed: %v", err)
		return -1
	}
	defer deleteHString(xamlText)

	// IXamlReaderStatics::Load (vtable index 6)
	var rootObject uintptr
	r := comCall(xamlReaderStatics, 6, xamlText, uintptr(unsafe.Pointer(&rootObject)))
	logState(fn, "IXamlReaderStatics::Load hr=0x%08X", uint32(r))
	if int32(r) < 0 {
		return int32(r)
	}
	defer releaseIf(&rootObject)

	// QueryInterface for IUIElement
	var rootElement uintptr
	hr2 := comQueryInterface(rootObject, &IID_IUIElement, &rootElement)
	logState(fn, "QI(IUIElement) hr=0x%08X", uint32(hr2))
	if hr2 < 0 {
		return hr2
	}
	defer releaseIf(&rootElement)

	// IDesktopWindowXamlSource::put_Content (vtable index 7)
	r = comCall(gDesktopWindowXamlSource, 7, rootElement)
	logState(fn, "IDesktopWindowXamlSource::put_Content hr=0x%08X", uint32(r))
	return int32(r)
}

// =====================================================================
// XAML Island initialization
// =====================================================================

func initializeXamlIsland(parentWindow uintptr) int32 {
	const fn = "initializeXamlIsland"

	hr := ensureDispatcherQueue()
	if hr < 0 {
		return hr
	}

	// Initialize WindowsXamlManager
	className, _ := createHString("Microsoft.UI.Xaml.Hosting.WindowsXamlManager")
	var xamlManagerStatics uintptr
	r, _, _ := procRoGetActivationFactory.Call(
		className,
		uintptr(unsafe.Pointer(&IID_IWindowsXamlManagerStatics)),
		uintptr(unsafe.Pointer(&xamlManagerStatics)))
	logState(fn, "RoGetActivationFactory(WindowsXamlManager) hr=0x%08X", uint32(r))
	if int32(r) < 0 {
		deleteHString(className)
		return int32(r)
	}

	// IWindowsXamlManagerStatics::InitializeForCurrentThread (vtable index 6)
	r2 := comCall(xamlManagerStatics, 6, uintptr(unsafe.Pointer(&gWindowsXamlManager)))
	logState(fn, "InitializeForCurrentThread hr=0x%08X", uint32(r2))
	if int32(r2) < 0 {
		// Retry after ensuring dispatcher queue
		ensureDispatcherQueue()
		r2 = comCall(xamlManagerStatics, 6, uintptr(unsafe.Pointer(&gWindowsXamlManager)))
		logState(fn, "InitializeForCurrentThread retry hr=0x%08X", uint32(r2))
	}
	if int32(r2) < 0 {
		logState(fn, "InitializeForCurrentThread failed; continuing with DesktopWindowXamlSource fallback")
	}
	releaseIf(&xamlManagerStatics)
	deleteHString(className)

	// Create DesktopWindowXamlSource
	className, _ = createHString("Microsoft.UI.Xaml.Hosting.DesktopWindowXamlSource")
	r, _, _ = procRoActivateInstance.Call(
		className,
		uintptr(unsafe.Pointer(&gDesktopWindowXamlSourceInspectable)))
	logState(fn, "RoActivateInstance(DesktopWindowXamlSource) hr=0x%08X", uint32(r))
	deleteHString(className)
	if int32(r) < 0 {
		return int32(r)
	}

	// QueryInterface for IDesktopWindowXamlSource
	hr2 := comQueryInterface(gDesktopWindowXamlSourceInspectable,
		&IID_IDesktopWindowXamlSource, &gDesktopWindowXamlSource)
	logState(fn, "QI(IDesktopWindowXamlSource) hr=0x%08X", uint32(hr2))
	if hr2 < 0 {
		return hr2
	}

	// Get WindowId for parent HWND
	windowId, hr3 := getWindowIdForHwnd(parentWindow)
	if hr3 < 0 {
		return hr3
	}

	// IDesktopWindowXamlSource::Initialize (vtable index 17)
	// WindowId is 8 bytes (uint64), passed by value in a register on x64
	r3 := comCall(gDesktopWindowXamlSource, 17, uintptr(windowId.Value))
	logState(fn, "IDesktopWindowXamlSource::Initialize hr=0x%08X", uint32(r3))
	if int32(r3) < 0 {
		return int32(r3)
	}

	return loadTriangleXaml()
}

func cleanupXamlIsland() {
	logState("cleanupXamlIsland", "begin")
	releaseIf(&gDesktopWindowXamlSource)
	releaseIf(&gDesktopWindowXamlSourceInspectable)
	releaseIf(&gWindowsXamlManager)
	releaseIf(&gCoreDispatcherQueueController)
	releaseIf(&gDispatcherQueueController)
	logState("cleanupXamlIsland", "end")
}

// =====================================================================
// Window procedure and creation
// =====================================================================

func wndProc(hwnd uintptr, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case WM_DESTROY:
		procPostQuitMessage.Call(0)
		return 0
	default:
		ret, _, _ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
		return ret
	}
}

func createMainWindow(instance uintptr) int32 {
	const fn = "createMainWindow"

	classNamePtr, _ := syscall.UTF16PtrFromString("HelloWinUI3GoWindow")
	cursorPtr, _, _ := procLoadCursorW.Call(0, IDC_ARROW)

	wcx := WNDCLASSEXW{
		Size:       uint32(unsafe.Sizeof(WNDCLASSEXW{})),
		Style:      CS_HREDRAW | CS_VREDRAW,
		WndProc:    syscall.NewCallback(wndProc),
		Instance:   instance,
		Cursor:     cursorPtr,
		Background: COLOR_WINDOW + 1,
		ClassName:  classNamePtr,
	}
	procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wcx)))

	rc := RECT{0, 0, 960, 540}
	procAdjustWindowRect.Call(
		uintptr(unsafe.Pointer(&rc)),
		WS_OVERLAPPEDWINDOW,
		0) // FALSE

	titlePtr, _ := syscall.UTF16PtrFromString("Hello, World!")
	gMainWindow, _, _ = procCreateWindowExW.Call(
		0,
		uintptr(unsafe.Pointer(classNamePtr)),
		uintptr(unsafe.Pointer(titlePtr)),
		WS_OVERLAPPEDWINDOW,
		CW_USEDEFAULT, CW_USEDEFAULT,
		uintptr(rc.Right-rc.Left),
		uintptr(rc.Bottom-rc.Top),
		0, 0, instance, 0)

	if gMainWindow == 0 {
		logState(fn, "CreateWindowExW failed")
		return -1
	}

	procShowWindow.Call(gMainWindow, SW_SHOW)
	procUpdateWindow.Call(gMainWindow)
	logState(fn, "window created hwnd=0x%X", gMainWindow)
	return 0 // S_OK
}

// =====================================================================
// Entry point
// =====================================================================

func main() {
	// Lock the main goroutine to the OS thread for COM STA
	runtime.LockOSThread()

	const fn = "main"
	logState(fn, "begin")

	bootstrapInitialized := false
	apartmentInitialized := false
	roInitialized := false

	// Initialize Windows App SDK bootstrap
	hr := mddBootstrapInit()
	logState(fn, "MddBootstrapInitialize2 hr=0x%08X", uint32(hr))
	if hr < 0 {
		msgBox("MddBootstrapInitialize2 failed.")
		return
	}
	bootstrapInitialized = true
	defer func() {
		if bootstrapInitialized {
			mddBootstrapDeinit()
			logState(fn, "MddBootstrapShutdown")
		}
	}()

	// Initialize COM apartment
	r, _, _ := procCoInitializeEx.Call(0, COINIT_APARTMENTTHREADED)
	logState(fn, "CoInitializeEx hr=0x%08X", uint32(r))
	if int32(r) >= 0 {
		apartmentInitialized = true
	} else if uint32(r) != 0x80010106 { // RPC_E_CHANGED_MODE
		msgBox("CoInitializeEx failed.")
		return
	}
	defer func() {
		if apartmentInitialized {
			procCoUninitialize.Call()
			logState(fn, "CoUninitialize")
		}
	}()

	// Initialize WinRT
	r, _, _ = procRoInitialize.Call(RO_INIT_SINGLETHREADED)
	logState(fn, "RoInitialize hr=0x%08X", uint32(r))
	if int32(r) >= 0 || uint32(r) == 1 { // S_OK or S_FALSE
		roInitialized = true
	} else if uint32(r) != 0x80010106 { // RPC_E_CHANGED_MODE
		msgBox("RoInitialize failed.")
		return
	}
	defer func() {
		if roInitialized {
			procRoUninitialize.Call()
			logState(fn, "RoUninitialize")
		}
	}()

	// Create dispatcher queue
	if ensureDispatcherQueue() < 0 {
		msgBox("EnsureDispatcherQueue failed.")
		return
	}

	// Get module handle
	instance, _, _ := procGetModuleHandleW.Call(0)

	// Create main window
	if createMainWindow(instance) < 0 {
		msgBox("Failed to create main window.")
		return
	}

	// Initialize XAML island
	hrXaml := initializeXamlIsland(gMainWindow)
	logState(fn, "initializeXamlIsland hr=0x%08X", uint32(hrXaml))
	if hrXaml < 0 {
		msgBox("Failed to initialize WinUI3 XAML island.")
		return
	}
	defer cleanupXamlIsland()

	// Message loop
	var msg MSG
	for {
		ret, _, _ := procGetMessageW.Call(
			uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
		if int32(ret) <= 0 {
			break
		}
		procTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
		procDispatchMessageW.Call(uintptr(unsafe.Pointer(&msg)))
	}

	logState(fn, "end")
}

func msgBox(text string) {
	textPtr, _ := syscall.UTF16PtrFromString(text)
	titlePtr, _ := syscall.UTF16PtrFromString("Error")
	procMessageBoxW.Call(0,
		uintptr(unsafe.Pointer(textPtr)),
		uintptr(unsafe.Pointer(titlePtr)),
		MB_ICONERROR|MB_OK)
}