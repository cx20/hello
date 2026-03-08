#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0A00
#endif

#include <atlbase.h>
#include <atlcomcli.h>
#include <tchar.h>
#include <initguid.h>
#include <roapi.h>
#include <Windows.ui.notifications.h>

DEFINE_GUID(UIID_IToastNotificationManagerStatics, 0x50ac103f, 0xd235, 0x4598, 0xbb, 0xef, 0x98, 0xfe, 0x4d, 0x1a, 0x3a, 0xd4);
DEFINE_GUID(UIID_IToastNotificationFactory,        0x04124b20, 0x82c6, 0x4229, 0xb1, 0x09, 0xfd, 0x9e, 0xd4, 0x66, 0x2b, 0x53);
DEFINE_GUID(UIID_IXmlDocument,                     0xf7f3a506, 0x1e87, 0x42d6, 0xbc, 0xfb, 0xb8, 0xc8, 0x09, 0xfa, 0x54, 0x94);
DEFINE_GUID(UIID_IXmlDocumentIO,                   0x6cd0e74e, 0xee65, 0x4489, 0x9e, 0xbf, 0xca, 0x43, 0xe8, 0x7b, 0xa6, 0x37);

#define APP_ID L"0123456789ABCDEF" // Dummy App ID for this sample

HRESULT CreateXmlDocumentFromString(
    const wchar_t* xmlString,
    __x_ABI_CWindows_CData_CXml_CDom_CIXmlDocument** doc)
{
    if (xmlString == NULL || doc == NULL)
    {
        return E_INVALIDARG;
    }

    *doc = NULL;

    HSTRING_HEADER xmlDocHeader;
    HSTRING xmlDocClass;
    HRESULT hr = WindowsCreateStringReference(
        RuntimeClass_Windows_Data_Xml_Dom_XmlDocument,
        (UINT32)wcslen(RuntimeClass_Windows_Data_Xml_Dom_XmlDocument),
        &xmlDocHeader,
        &xmlDocClass);
    if (FAILED(hr))
    {
        return hr;
    }

    CComPtr<IInspectable> inspectable;
    hr = RoActivateInstance(xmlDocClass, &inspectable);
    if (FAILED(hr))
    {
        return hr;
    }

    CComPtr<__x_ABI_CWindows_CData_CXml_CDom_CIXmlDocument> xmlDoc;
    hr = inspectable->QueryInterface(UIID_IXmlDocument, (void**)&xmlDoc);
    if (FAILED(hr))
    {
        return hr;
    }

    CComPtr<__x_ABI_CWindows_CData_CXml_CDom_CIXmlDocumentIO> docIO;
    hr = xmlDoc->QueryInterface(UIID_IXmlDocumentIO, (void**)&docIO);
    if (FAILED(hr))
    {
        return hr;
    }

    HSTRING_HEADER xmlHeader;
    HSTRING xmlHString;
    hr = WindowsCreateStringReference(
        xmlString,
        (UINT32)wcslen(xmlString),
        &xmlHeader,
        &xmlHString);
    if (FAILED(hr))
    {
        return hr;
    }

    hr = docIO->LoadXml(xmlHString);
    if (FAILED(hr))
    {
        return hr;
    }

    *doc = xmlDoc.Detach();
    return S_OK;
}

HRESULT ShowToast()
{
    // Initialize WinRT in the current thread.
    HRESULT hr = RoInitialize(RO_INIT_MULTITHREADED);
    if (FAILED(hr) && hr != S_FALSE)
    {
        return hr;
    }
    const bool needUninitialize = (hr == S_OK || hr == S_FALSE);

    HSTRING_HEADER appIdHeader;
    HSTRING appId;
    hr = WindowsCreateStringReference(APP_ID, (UINT32)wcslen(APP_ID), &appIdHeader, &appId);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    CComPtr<__x_ABI_CWindows_CData_CXml_CDom_CIXmlDocument> inputXml;
    hr = CreateXmlDocumentFromString(
        L"<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">\r\n"
        L"    <visual>\r\n"
        L"        <binding template=\"ToastGeneric\">\r\n"
        L"            <text><![CDATA[Hello, WinRT(ATL) World!]]></text>\r\n"
        L"        </binding>\r\n"
        L"    </visual>\r\n"
        L"    <audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />\r\n"
        L"</toast>\r\n",
        &inputXml);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    HSTRING_HEADER toastMgrHeader;
    HSTRING toastMgrClass;
    hr = WindowsCreateStringReference(
        RuntimeClass_Windows_UI_Notifications_ToastNotificationManager,
        (UINT32)wcslen(RuntimeClass_Windows_UI_Notifications_ToastNotificationManager),
        &toastMgrHeader,
        &toastMgrClass);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    CComPtr<__x_ABI_CWindows_CUI_CNotifications_CIToastNotificationManagerStatics> toastStatics;
    hr = RoGetActivationFactory(toastMgrClass, UIID_IToastNotificationManagerStatics, (LPVOID*)&toastStatics);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    CComPtr<__x_ABI_CWindows_CUI_CNotifications_CIToastNotifier> notifier;
    hr = toastStatics->CreateToastNotifierWithId(appId, &notifier);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    HSTRING_HEADER toastHeader;
    HSTRING toastClass;
    hr = WindowsCreateStringReference(
        RuntimeClass_Windows_UI_Notifications_ToastNotification,
        (UINT32)wcslen(RuntimeClass_Windows_UI_Notifications_ToastNotification),
        &toastHeader,
        &toastClass);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    CComPtr<__x_ABI_CWindows_CUI_CNotifications_CIToastNotificationFactory> notifFactory;
    hr = RoGetActivationFactory(toastClass, UIID_IToastNotificationFactory, (LPVOID*)&notifFactory);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    CComPtr<__x_ABI_CWindows_CUI_CNotifications_CIToastNotification> toast;
    hr = notifFactory->CreateToastNotification(inputXml, &toast);
    if (FAILED(hr))
    {
        if (needUninitialize) RoUninitialize();
        return hr;
    }

    hr = notifier->Show(toast);

    if (needUninitialize)
    {
        RoUninitialize();
    }

    return hr;
}

int APIENTRY _tWinMain(HINSTANCE, HINSTANCE, LPTSTR, int)
{
    const HRESULT hr = ShowToast();
    if (FAILED(hr))
    {
        wchar_t message[128];
        wsprintfW(message, L"Failed to show toast notification. HRESULT=0x%08X", (unsigned int)hr);
        ::MessageBoxW(NULL, message, L"Error", MB_ICONERROR | MB_OK);
    }
    return FAILED(hr) ? 1 : 0;
}
