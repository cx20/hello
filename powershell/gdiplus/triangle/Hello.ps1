# Do not stop the script on error (just in case)
$ErrorActionPreference = "Continue"

Write-Host "[(1) Start] Loading assemblies..."
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Write-Host "[(2) Success] Assemblies loaded."
}
catch {
    Write-Host "[(ERROR) Assembly load failed] $_" -ForegroundColor Red
    exit
}

Write-Host "[(3) Progress] Creating form object..."
$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(640, 480)
$form.Text = "Hello, World!"
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

# Force the window to the top (in case it is hidden behind other windows)
$form.TopMost = $true

Write-Host "[(4) Progress] Defining Paint event handler..."
$paintAction = {
    param($sender, $e)

    # Confirm event occurrence
    Write-Host "[(EVENT) Paint triggered] Starting drawing process..." -ForegroundColor Cyan

    try {
        # Get drawing area size
        $WIDTH  = $sender.ClientSize.Width
        $HEIGHT = $sender.ClientSize.Height
        
        Write-Host "    -> Drawing area: W=$WIDTH, H=$HEIGHT"

        # Create GraphicsPath
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath

        # Create array of Points
        $p1 = New-Object System.Drawing.Point([int]($WIDTH * 1 / 2), [int]($HEIGHT * 1 / 4))
        $p2 = New-Object System.Drawing.Point([int]($WIDTH * 3 / 4), [int]($HEIGHT * 3 / 4))
        $p3 = New-Object System.Drawing.Point([int]($WIDTH * 1 / 4), [int]($HEIGHT * 3 / 4))
        
        $points = [System.Drawing.Point[]] @($p1, $p2, $p3)
        $path.AddLines($points)
        
        # Create PathGradientBrush
        $pthGrBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)

        # Set center color (255/3 approx 85)
        $pthGrBrush.CenterColor = [System.Drawing.Color]::FromArgb(255, 85, 85, 85)

        # Set surround colors
        $pthGrBrush.SurroundColors = [System.Drawing.Color[]] @(
            [System.Drawing.Color]::FromArgb(255, 255,   0,   0),
            [System.Drawing.Color]::FromArgb(255,   0, 255,   0),
            [System.Drawing.Color]::FromArgb(255,   0,   0, 255)
        )

        # Execute drawing
        $e.Graphics.FillPath($pthGrBrush, $path)
        
        # Dispose resources
        $path.Dispose()
        $pthGrBrush.Dispose()

        Write-Host "[(EVENT) Complete] Drawing process finished successfully." -ForegroundColor Cyan
    }
    catch {
        Write-Host "[(ERROR) Drawing Error] An error occurred inside Paint event: $_" -ForegroundColor Red
    }
}

# Register event
$form.Add_Paint($paintAction)

Write-Host "[(5) Execute] Calling ShowDialog(). The window should appear..."

# Show form
$result = $form.ShowDialog()

Write-Host "[(6) End] Window closed (Result: $result)"
