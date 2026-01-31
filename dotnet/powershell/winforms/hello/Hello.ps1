[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
$form = New-Object Windows.Forms.Form
$form.Size = New-Object Drawing.Size 640,480
$form.Text = "Hello, World!"
$label1 = New-Object Windows.Forms.Label
$label1.Size = New-Object Drawing.Size 320, 20
$label1.Text = "Hello, Windows Forms(PowerShell) World!"
$form.Controls.Add( $label1 )
$form.ShowDialog()
