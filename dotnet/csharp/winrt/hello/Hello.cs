// Hello.cs - WinRT Toast (Desktop / no UWP)
// Build with csc.exe by referencing Windows.winmd (see command below)

using System;
using System.Runtime.InteropServices;
using System.Threading;
using Windows.Data.Xml.Dom;
using Windows.UI.Notifications;

class Hello
{
    // Helps desktop toast routing (AUMID hint)
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern int SetCurrentProcessExplicitAppUserModelID(string appID);

    [STAThread]
    static void Main()
    {
        const string AppId = "Hello, World!"; // match your working C++ sample

        // Ignore errors; toast may still work depending on environment.
        SetCurrentProcessExplicitAppUserModelID(AppId);

        var xml = new XmlDocument();
        xml.LoadXml(
            "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">" +
            "  <visual>" +
            "    <binding template=\"ToastGeneric\">" +
            "      <text><![CDATA[Hello, WinRT(C#) World!]]></text>" +
            "    </binding>" +
            "  </visual>" +
            "  <audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />" +
            "</toast>"
        );

        var toast = new ToastNotification(xml);

        // Desktop: use notifier with explicit ID (like your C++ sample)
        var notifier = ToastNotificationManager.CreateToastNotifier(AppId);
        notifier.Show(toast);

        // Keep process alive a bit so the banner has time to appear
        Thread.Sleep(3000);
    }
}