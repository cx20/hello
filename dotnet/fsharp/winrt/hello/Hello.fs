// Hello.fs - WinRT Toast (Desktop / no UWP)
// Build with build.bat (fsc + ildasm/ilasm post-processing)
//
// fsc does not emit the 'windowsruntime' flag on the 'Windows' AssemblyRef
// (unlike csc/vbc), so the CLR cannot resolve it via the WinRT type loader.
// build.bat patches the IL after compilation to add the flag.

open System
open System.Runtime.InteropServices
open System.Threading
open Windows.Data.Xml.Dom
open Windows.UI.Notifications

// Helps desktop toast routing (AUMID hint)
[<DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)>]
extern int SetCurrentProcessExplicitAppUserModelID(string appID)

[<STAThread>]
[<EntryPoint>]
let main _ =
    let appId = "Hello, World!"

    // Ignore errors; toast may still work depending on environment.
    SetCurrentProcessExplicitAppUserModelID(appId) |> ignore

    let xml = XmlDocument()
    xml.LoadXml(
        "<toast activationType=\"protocol\" launch=\"imsprevn://0\" duration=\"long\">" +
        "  <visual>" +
        "    <binding template=\"ToastGeneric\">" +
        "      <text><![CDATA[Hello, WinRT(F#) World!]]></text>" +
        "    </binding>" +
        "  </visual>" +
        "  <audio src=\"ms-winsoundevent:Notification.Mail\" loop=\"false\" />" +
        "</toast>"
    )

    let toast = ToastNotification(xml)

    // Desktop: use notifier with explicit ID (like your C++ sample)
    let notifier = ToastNotificationManager.CreateToastNotifier(appId)
    notifier.Show(toast)

    // Keep process alive a bit so the banner has time to appear
    Thread.Sleep(3000)
    0
