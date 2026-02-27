package main

/*
 * hello.go
 *
 * Display a Windows Toast notification using raw WinRT COM vtable calls.
 * Pure Go (no cgo) — mirrors the C implementation that uses
 * RoInitialize, RoActivateInstance, RoGetActivationFactory, and HSTRING.
 *
 * Build:
 *   go build -ldflags "-H windowsgui" hello.go
 */

import (
	"syscall"
	"time"
	"unsafe"
)

// ============================================================
// GUIDs
// ============================================================

type GUID struct {
	Data1 uint32
	Data2 uint16
	Data3 uint16
	Data4 [8]byte
}

// IToastNotificationManagerStatics {50AC103F-D235-4598-BBEF-98FE4D1A3AD4}
var IID_IToastNotificationManagerStatics = GUID{
	0x50ac103f, 0xd235, 0x4598,
	[8]byte{0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4},
}

// IToastNotificationFactory {04124B20-82C6-4229-B109-FD9ED4662B53}
var IID_IToastNotificationFactory = GUID{
	0x04124b20, 0x82c6, 0x4229,
	[8]byte{0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53},
}

// IXmlDocument {F7F3A506-1E87-42D6-BCFB-B8C809FA5494}
var IID_IXmlDocument = GUID{
	0xf7f3a506, 0x1e87, 0x42d6,
	[8]byte{0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94},
}

// IXmlDocumentIO {6CD0E74E-EE65-4489-9EBF-CA43E87BA637}
var IID_IXmlDocumentIO = GUID{
	0x6cd0e74e, 0xee65, 0x4489,
	[8]byte{0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37},
}

// ============================================================
// WinRT runtime class names
// ============================================================

const (
	runtimeXmlDocument               = "Windows.Data.Xml.Dom.XmlDocument"
	runtimeToastNotificationManager  = "Windows.UI.Notifications.ToastNotificationManager"
	runtimeToastNotification         = "Windows.UI.Notifications.ToastNotification"
)

// ============================================================
// DLL / proc declarations
// ============================================================

var (
	combase = syscall.NewLazyDLL("combase.dll")

	pRoInitialize                  = combase.NewProc("RoInitialize")
	pRoUninitialize                = combase.NewProc("RoUninitialize")
	pRoActivateInstance            = combase.NewProc("RoActivateInstance")
	pRoGetActivationFactory        = combase.NewProc("RoGetActivationFactory")
	pWindowsCreateStringReference  = combase.NewProc("WindowsCreateStringReference")

	kernel32 = syscall.NewLazyDLL("kernel32.dll")
)

const (
	RO_INIT_MULTITHREADED = 1
)

// ============================================================
// HSTRING helpers
// ============================================================

// HSTRING_HEADER is an opaque structure used by WindowsCreateStringReference.
// On 64-bit Windows its size is 24 bytes.
type HSTRING_HEADER struct {
	_ [24]byte
}

// createStringRef creates a stack-based HSTRING reference from a Go string.
// The returned HSTRING is only valid while the header and UTF-16 slice are alive.
func createStringRef(s string) (uintptr, *HSTRING_HEADER, []uint16) {
	utf16 := syscall.StringToUTF16(s)
	// StringToUTF16 appends a null terminator; length excludes it
	length := uint32(len(utf16) - 1)

	var header HSTRING_HEADER
	var hstring uintptr

	pWindowsCreateStringReference.Call(
		uintptr(unsafe.Pointer(&utf16[0])),
		uintptr(length),
		uintptr(unsafe.Pointer(&header)),
		uintptr(unsafe.Pointer(&hstring)),
	)

	return hstring, &header, utf16
}

// ============================================================
// COM vtable helpers
// ============================================================

// comCall invokes the COM method at vtable[index] on obj.
func comCall(obj uintptr, index int, args ...uintptr) uintptr {
	vtbl := *(*uintptr)(unsafe.Pointer(obj))
	method := *(*uintptr)(unsafe.Pointer(vtbl + uintptr(index)*unsafe.Sizeof(uintptr(0))))
	all := make([]uintptr, 0, 1+len(args))
	all = append(all, obj)
	all = append(all, args...)
	ret, _, _ := syscall.SyscallN(method, all...)
	return ret
}

// comRelease calls IUnknown::Release (vtable slot 2).
func comRelease(obj uintptr) {
	if obj != 0 {
		comCall(obj, 2)
	}
}

// comQI calls IUnknown::QueryInterface (vtable slot 0).
func comQI(obj uintptr, iid *GUID, out *uintptr) uintptr {
	return comCall(obj, 0, uintptr(unsafe.Pointer(iid)), uintptr(unsafe.Pointer(out)))
}

// ============================================================
// WinRT vtable slot indices
//
// WinRT interfaces inherit from IInspectable which has 6 slots:
//   0: QueryInterface  1: AddRef  2: Release
//   3: GetIids  4: GetRuntimeClassName  5: GetTrustLevel
// Interface-specific methods start at slot 6.
// ============================================================

const (
	// IXmlDocumentIO
	//   slot 6: LoadXml(HSTRING)
	ixmlDocIOLoadXml = 6

	// IToastNotificationManagerStatics
	//   slot 6:  CreateToastNotifierDefault
	//   slot 7:  CreateToastNotifierWithId(HSTRING, IToastNotifier**)
	itoastMgrCreateNotifierWithId = 7

	// IToastNotificationFactory
	//   slot 6:  CreateToastNotification(IXmlDocument*, IToastNotification**)
	itoastFactoryCreate = 6

	// IToastNotifier
	//   slot 6:  Show(IToastNotification*)
	itoastNotifierShow = 6
)

// ============================================================
// Create XmlDocument from XML string
// ============================================================

func createXmlDocumentFromString(xmlString string) (uintptr, error) {
	// Activate Windows.Data.Xml.Dom.XmlDocument
	hsClass, _, _ := createStringRef(runtimeXmlDocument)

	var inspectable uintptr
	hr, _, _ := pRoActivateInstance.Call(hsClass, uintptr(unsafe.Pointer(&inspectable)))
	if hr != 0 {
		return 0, syscall.Errno(hr)
	}
	defer comRelease(inspectable)

	// QueryInterface for IXmlDocument
	var doc uintptr
	comQI(inspectable, &IID_IXmlDocument, &doc)

	// QueryInterface for IXmlDocumentIO
	var docIO uintptr
	comQI(doc, &IID_IXmlDocumentIO, &docIO)
	defer comRelease(docIO)

	// LoadXml
	hsXml, _, _ := createStringRef(xmlString)
	comCall(docIO, ixmlDocIOLoadXml, hsXml)

	return doc, nil
}

// ============================================================
// Main
// ============================================================

func main() {
	// RoInitialize(RO_INIT_MULTITHREADED)
	hr, _, _ := pRoInitialize.Call(RO_INIT_MULTITHREADED)
	if hr != 0 && hr != 1 { // S_OK or S_FALSE (already initialized)
		return
	}
	defer pRoUninitialize.Call()

	// App ID (dummy — for real apps, use an AUMID registered in the Start menu)
	appID := "0123456789ABCDEF"
	hsAppID, _, _ := createStringRef(appID)

	// Create XML document from toast XML
	toastXML :=
		"<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n" +
			"	<visual>\r\n" +
			"		<binding template=\"ToastGeneric\">\r\n" +
			"			<text><![CDATA[Hello, WinRT(Go) World!]]></text>\r\n" +
			"		</binding>\r\n" +
			"	</visual>\r\n" +
			"	<audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n" +
			"</toast>\r\n"

	inputXml, err := createXmlDocumentFromString(toastXML)
	if err != nil {
		return
	}
	defer comRelease(inputXml)

	// Get IToastNotificationManagerStatics
	hsToastMgr, _, _ := createStringRef(runtimeToastNotificationManager)

	var toastStatics uintptr
	hr, _, _ = pRoGetActivationFactory.Call(
		hsToastMgr,
		uintptr(unsafe.Pointer(&IID_IToastNotificationManagerStatics)),
		uintptr(unsafe.Pointer(&toastStatics)),
	)
	if hr != 0 {
		return
	}
	defer comRelease(toastStatics)

	// CreateToastNotifierWithId
	var notifier uintptr
	comCall(toastStatics, itoastMgrCreateNotifierWithId,
		hsAppID, uintptr(unsafe.Pointer(&notifier)))
	defer comRelease(notifier)

	// Get IToastNotificationFactory
	hsToastNotif, _, _ := createStringRef(runtimeToastNotification)

	var notifFactory uintptr
	hr, _, _ = pRoGetActivationFactory.Call(
		hsToastNotif,
		uintptr(unsafe.Pointer(&IID_IToastNotificationFactory)),
		uintptr(unsafe.Pointer(&notifFactory)),
	)
	if hr != 0 {
		return
	}
	defer comRelease(notifFactory)

	// CreateToastNotification(inputXml)
	var toast uintptr
	comCall(notifFactory, itoastFactoryCreate,
		inputXml, uintptr(unsafe.Pointer(&toast)))
	defer comRelease(toast)

	// Show the toast
	comCall(notifier, itoastNotifierShow, toast)

	// Brief sleep to allow the notification to be dispatched
	time.Sleep(time.Millisecond)
}