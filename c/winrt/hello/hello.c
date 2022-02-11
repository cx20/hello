// forked from https://stackoverflow.com/questions/65387849/consume-windows-runtime-apis-from-pure-c

#include <initguid.h>
#include <roapi.h>
#include <Windows.ui.notifications.h>

DEFINE_GUID(UIID_IToastNotificationManagerStatics, 0x50ac103f, 0xd235, 0x4598, 0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4);
DEFINE_GUID(UIID_IToastNotificationFactory,        0x04124b20, 0x82c6, 0x4229, 0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53);
DEFINE_GUID(UIID_IXmlDocument,                     0xf7f3a506, 0x1e87, 0x42d6, 0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94);
DEFINE_GUID(UIID_IXmlDocumentIO,                   0x6cd0e74e, 0xee65, 0x4489, 0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37);

#define APP_ID L"0123456789ABCDEF" // Dummy App ID

HRESULT CreateXmlDocumentFromString(
	const wchar_t* xmlString, 
	__x_ABI_CWindows_CData_CXml_CDom_CIXmlDocument** doc
)
{
	HSTRING_HEADER header_IXmlDocumentHString;
	HSTRING IXmlDocumentHString;
	WindowsCreateStringReference(
		RuntimeClass_Windows_Data_Xml_Dom_XmlDocument,
		(UINT32)wcslen(RuntimeClass_Windows_Data_Xml_Dom_XmlDocument),
		&header_IXmlDocumentHString,
		&IXmlDocumentHString
	);

	IInspectable* pInspectable;
	RoActivateInstance(IXmlDocumentHString, &pInspectable);
	pInspectable->lpVtbl->QueryInterface(
		pInspectable,
		&UIID_IXmlDocument,
		doc
	);
	pInspectable->lpVtbl->Release(pInspectable);

	__x_ABI_CWindows_CData_CXml_CDom_CIXmlDocumentIO* docIO;
	(*doc)->lpVtbl->QueryInterface(
		(*doc),
		&UIID_IXmlDocumentIO,
		&docIO
	);

	HSTRING_HEADER header_XmlString;
	HSTRING XmlString;
	WindowsCreateStringReference(
		xmlString,
		(UINT32)wcslen(xmlString),
		&header_XmlString,
		&XmlString
	);

	docIO->lpVtbl->LoadXml(docIO, XmlString);
	docIO->lpVtbl->Release(docIO);

	return 0;
}

int APIENTRY wWinMain(
	HINSTANCE hInstance,
	HINSTANCE hPrevInstance,
	LPWSTR lpCmdLine,
	int nShowCmd
) 
{
	RoInitialize(RO_INIT_MULTITHREADED);

	HSTRING_HEADER header_AppIdHString;
	HSTRING AppIdHString;
	WindowsCreateStringReference(
		APP_ID,
		(UINT32)wcslen(APP_ID),
		&header_AppIdHString,
		&AppIdHString
	);

	__x_ABI_CWindows_CData_CXml_CDom_CIXmlDocument* inputXml = NULL;
	CreateXmlDocumentFromString(
		L"<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n"
		L"	<visual>\r\n"
		L"		<binding template=\"ToastGeneric\">\r\n"
		L"			<text><![CDATA[Hello, WinRT World!]]></text>\r\n"
		L"		</binding>\r\n"
		L"	</visual>\r\n"
		L"	<audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n"
		L"</toast>\r\n"
		, &inputXml
	);

	HSTRING_HEADER header_ToastNotificationManagerHString;
	HSTRING ToastNotificationManagerHString;
	WindowsCreateStringReference(
		RuntimeClass_Windows_UI_Notifications_ToastNotificationManager,
		(UINT32)wcslen(RuntimeClass_Windows_UI_Notifications_ToastNotificationManager),
		&header_ToastNotificationManagerHString,
		&ToastNotificationManagerHString
	);

	__x_ABI_CWindows_CUI_CNotifications_CIToastNotificationManagerStatics* toastStatics = NULL;
	RoGetActivationFactory(
		ToastNotificationManagerHString,
		&UIID_IToastNotificationManagerStatics,
		(LPVOID*)&toastStatics
	);

	__x_ABI_CWindows_CUI_CNotifications_CIToastNotifier* notifier;
	toastStatics->lpVtbl->CreateToastNotifierWithId(
		toastStatics, 
		AppIdHString, 
		&notifier
	);
	
	HSTRING_HEADER header_ToastNotificationHString;
	HSTRING ToastNotificationHString;
	WindowsCreateStringReference(
		RuntimeClass_Windows_UI_Notifications_ToastNotification,
		(UINT32)wcslen(RuntimeClass_Windows_UI_Notifications_ToastNotification),
		&header_ToastNotificationHString,
		&ToastNotificationHString
	);

	__x_ABI_CWindows_CUI_CNotifications_CIToastNotificationFactory* notifFactory = NULL;
	RoGetActivationFactory(
		ToastNotificationHString,
		&UIID_IToastNotificationFactory,
		(LPVOID*)&notifFactory
	);

	__x_ABI_CWindows_CUI_CNotifications_CIToastNotification* toast = NULL;
	notifFactory->lpVtbl->CreateToastNotification(notifFactory, inputXml, &toast);

	notifier->lpVtbl->Show(notifier, toast);

	Sleep(1);

	toast->lpVtbl->Release(toast);
	notifFactory->lpVtbl->Release(notifFactory);
	notifier->lpVtbl->Release(notifier);
	toastStatics->lpVtbl->Release(toastStatics);
	inputXml->lpVtbl->Release(inputXml);
	RoUninitialize();

	return 0;
}
