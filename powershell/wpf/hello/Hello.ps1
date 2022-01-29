using namespace System.Xml
Add-Type -AssemblyName PresentationFramework
[xml]$xaml = Get-Content .\Hello.xaml
$nodeReader = (New-Object XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($nodeReader)
$window.ShowDialog()
