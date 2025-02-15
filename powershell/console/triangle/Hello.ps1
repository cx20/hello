# Define a function to determine the nearest approximate ConsoleColor based on RGB values.
function Get-NearestConsoleColor {
    param (
        [int]$r,
        [int]$g,
        [int]$b
    )

    # Define approximate RGB values for each ConsoleColor.
    $colors = @{
        'Black'       = @{ r = 0;   g = 0;   b = 0 }
        'DarkBlue'    = @{ r = 0;   g = 0;   b = 128 }
        'DarkGreen'   = @{ r = 0;   g = 128; b = 0 }
        'DarkCyan'    = @{ r = 0;   g = 128; b = 128 }
        'DarkRed'     = @{ r = 128; g = 0;   b = 0 }
        'DarkMagenta' = @{ r = 128; g = 0;   b = 128 }
        'DarkYellow'  = @{ r = 128; g = 128; b = 0 }
        'Gray'        = @{ r = 192; g = 192; b = 192 }
        'DarkGray'    = @{ r = 128; g = 128; b = 128 }
        'Blue'        = @{ r = 0;   g = 0;   b = 255 }
        'Green'       = @{ r = 0;   g = 255; b = 0 }
        'Cyan'        = @{ r = 0;   g = 255; b = 255 }
        'Red'         = @{ r = 255; g = 0;   b = 0 }
        'Magenta'     = @{ r = 255; g = 0;   b = 255 }
        'Yellow'      = @{ r = 255; g = 255; b = 0 }
        'White'       = @{ r = 255; g = 255; b = 255 }
    }

    $bestColor = $null
    $bestDistance = [double]::MaxValue

    # Loop through each color to find the nearest match using Euclidean distance in RGB space.
    foreach ($color in $colors.Keys) {
        $cr = $colors[$color].r
        $cg = $colors[$color].g
        $cb = $colors[$color].b
        # Calculate the Euclidean distance in RGB space.
        $distance = [math]::Sqrt( ($r - $cr) * ($r - $cr) + ($g - $cg) * ($g - $cg) + ($b - $cb) * ($b - $cb) )
        if ($distance -lt $bestDistance) {
            $bestDistance = $distance
            $bestColor = $color
        }
    }
    return $bestColor
}

# Define the height of the triangle (number of rows).
$height = 10

# Output each row of the triangle.
for ($i = 0; $i -lt $height; $i++) {
    # Add left padding spaces to center-align the triangle.
    $padding = " " * ($height - $i)
    Write-Host -NoNewline $padding

    # Each row will have (2*$i + 1) characters.
    for ($j = 0; $j -lt (2 * $i + 1); $j++) {
        # Calculate the horizontal ratio 's' for the current cell (range: 0 to 1).
        if ($i -eq 0) {
            $s = 0.5  # The first row has only one character, so set s to 0.5.
        } else {
            $s = $j / (2 * $i)
        }
        # Calculate the vertical ratio 't' (0 at the top, 1 at the bottom).
        $t = $i / ($height - 1)

        # Calculate each color component using simple linear interpolation:
        # Top vertex (t=0) is Red: (255, 0, 0).
        # Bottom-left vertex (s=0, t=1) is Blue: (0, 0, 255).
        # Bottom-right vertex (s=1, t=1) is Green: (0, 255, 0).
        $R = [int](255 * (1 - $t))
        $B = [int](255 * $t * (1 - $s))
        $G = [int](255 * $t * $s)

        # Determine the nearest ConsoleColor for the calculated RGB value.
        $consoleColor = Get-NearestConsoleColor -r $R -g $G -b $B

        Write-Host "*" -ForegroundColor $consoleColor -NoNewline
    }
    Write-Host ""
}
