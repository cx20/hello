# Load WinRT assemblies for Toast Notifications
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null

# Set AUMID for desktop toast routing
$shell32 = Add-Type -Name "Shell32" -Namespace "Win32" -PassThru -MemberDefinition @"
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
"@

$AppId = "Hello, World!"
[void]$shell32::SetCurrentProcessExplicitAppUserModelID($AppId)

# Build toast XML
$xmlString = @"
<toast activationType="protocol" launch="imsprevn://0" duration="long">
  <visual>
    <binding template="ToastGeneric">
      <text><![CDATA[Hello, WinRT(PowerShell) World!]]></text>
    </binding>
  </visual>
  <audio src="ms-winsoundevent:Notification.Mail" loop="false" />
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($xmlString)

# Create and show the toast notification
$toast = New-Object Windows.UI.Notifications.ToastNotification($xml)
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
$notifier.Show($toast)

# Keep process alive so the banner has time to appear
Start-Sleep -Seconds 3
