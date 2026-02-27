// Windows Toast Notification sample using WinRT APIs in Rust
// forked from https://stackoverflow.com/questions/65387849/consume-windows-runtime-apis-from-pure-c

use windows::{
    core::*,
    Data::Xml::Dom::XmlDocument,
    UI::Notifications::{ToastNotification, ToastNotificationManager},
};

fn main() -> Result<()> {
    // Dummy App ID
    const APP_ID: &str = "0123456789ABCDEF";

    // Define the toast XML content
    let toast_xml_str = r#"<toast activationType="protocol" launch="imsprevn://0" duration="long">
    <visual>
        <binding template="ToastGeneric">
            <text><![CDATA[Hello, WinRT World!]]></text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Mail" loop="false" />
</toast>"#;

    // Create an XmlDocument and load the toast XML string
    let xml_doc = XmlDocument::new()?;
    xml_doc.LoadXml(&HSTRING::from(toast_xml_str))?;

    // Create a toast notifier with the specified App ID
    let notifier = ToastNotificationManager::CreateToastNotifierWithId(&HSTRING::from(APP_ID))?;

    // Create a toast notification from the XML document
    let toast = ToastNotification::CreateToastNotification(&xml_doc)?;

    // Show the toast notification
    notifier.Show(&toast)?;

    // Brief sleep to allow the notification to be displayed
    std::thread::sleep(std::time::Duration::from_millis(1));

    Ok(())
}