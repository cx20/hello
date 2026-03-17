Imports System
Imports System.Runtime.InteropServices
Imports System.Threading
Imports Windows.Data.Xml.Dom
Imports Windows.UI.Notifications

Module Hello
    ' Helps desktop toast routing (AUMID hint).
    <DllImport("shell32.dll", CharSet:=CharSet.Unicode, SetLastError:=True)>
    Private Function SetCurrentProcessExplicitAppUserModelID(ByVal appID As String) As Integer
    End Function

    <STAThread>
    Sub Main()
        Const AppId As String = "Hello, World!"

        ' Ignore errors; toast may still work depending on environment.
        SetCurrentProcessExplicitAppUserModelID(AppId)

        Dim xml As New XmlDocument()
        xml.LoadXml(
            "<toast activationType=""protocol"" launch=""imsprevn://0"" duration=""long"">" &
            "  <visual>" &
            "    <binding template=""ToastGeneric"">" &
            "      <text><![CDATA[Hello, WinRT(VB.NET) World!]]></text>" &
            "    </binding>" &
            "  </visual>" &
            "  <audio src=""ms-winsoundevent:Notification.Mail"" loop=""false"" />" &
            "</toast>"
        )

        Dim toast As New ToastNotification(xml)
        Dim notifier = ToastNotificationManager.CreateToastNotifier(AppId)
        notifier.Show(toast)

        ' Keep process alive a bit so the banner has time to appear.
        Thread.Sleep(3000)
    End Sub
End Module
