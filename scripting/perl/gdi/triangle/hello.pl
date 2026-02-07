use strict;
use warnings;
use Win32::GUI();
use Win32::API;

# Window dimensions
my $width  = 640;
my $height = 480;

# Import GDI32 and User32 functions
Win32::API->Import('user32', 'HDC GetDC(HWND hWnd)');
Win32::API->Import('user32', 'int ReleaseDC(HWND hWnd, HDC hDC)');

# Import GradientFill from msimg32.dll
# BOOL GradientFill(HDC hdc, PTRIVERTEX pVertex, ULONG nVertex, PVOID pMesh, ULONG nMesh, ULONG ulMode)
Win32::API->Import('msimg32', 'BOOL GradientFill(HDC hdc, LPVOID pVertex, DWORD nVertex, LPVOID pMesh, DWORD nMesh, DWORD ulMode)');

# GRADIENT_FILL_TRIANGLE constant
use constant GRADIENT_FILL_TRIANGLE => 2;

# Create main window
my $main = Win32::GUI::Window->new(
    -name   => "Main",
    -text   => "Perl Win32 GDI Gradient Triangle",
    -left   => 100,
    -top    => 100,
    -width  => $width,
    -height => $height,
);

sub dbg {
    my ($func, $state) = @_;
    print STDERR "[$func] $state\n";
}

sub DrawGradientTriangle {
    my $hwnd = $main->{-handle};
    dbg("DrawGradientTriangle", "HWND=$hwnd");
    
    my $hdc = GetDC($hwnd);
    dbg("DrawGradientTriangle", "HDC=$hdc");
    
    return 0 unless $hdc;

    my ($left, $top, $right, $bottom) = $main->GetClientRect();
    my $w = $right - $left;
    my $h = $bottom - $top;
    dbg("DrawGradientTriangle", "ClientRect: ${w}x${h}");

    # TRIVERTEX structure (16 bytes each):
    #   LONG x        (4 bytes)
    #   LONG y        (4 bytes)
    #   COLOR16 Red   (2 bytes, unsigned short)
    #   COLOR16 Green (2 bytes)
    #   COLOR16 Blue  (2 bytes)
    #   COLOR16 Alpha (2 bytes)
    # Pack format: "l l S S S S"

    # Vertex 0: Top center (Red)
    my $v0_x     = int($w / 2);
    my $v0_y     = int($h / 4);
    my $v0_red   = 0xFFFF;
    my $v0_green = 0x0000;
    my $v0_blue  = 0x0000;
    my $v0_alpha = 0x0000;

    # Vertex 1: Bottom right (Green)
    my $v1_x     = int($w * 3 / 4);
    my $v1_y     = int($h * 3 / 4);
    my $v1_red   = 0x0000;
    my $v1_green = 0xFFFF;
    my $v1_blue  = 0x0000;
    my $v1_alpha = 0x0000;

    # Vertex 2: Bottom left (Blue)
    my $v2_x     = int($w / 4);
    my $v2_y     = int($h * 3 / 4);
    my $v2_red   = 0x0000;
    my $v2_green = 0x0000;
    my $v2_blue  = 0xFFFF;
    my $v2_alpha = 0x0000;

    dbg("DrawGradientTriangle", "V0: ($v0_x, $v0_y) Red");
    dbg("DrawGradientTriangle", "V1: ($v1_x, $v1_y) Green");
    dbg("DrawGradientTriangle", "V2: ($v2_x, $v2_y) Blue");

    # Pack TRIVERTEX array (3 vertices)
    my $vertices = pack("l l S S S S" x 3,
        $v0_x, $v0_y, $v0_red, $v0_green, $v0_blue, $v0_alpha,
        $v1_x, $v1_y, $v1_red, $v1_green, $v1_blue, $v1_alpha,
        $v2_x, $v2_y, $v2_red, $v2_green, $v2_blue, $v2_alpha,
    );

    dbg("DrawGradientTriangle", "Vertices packed, length=" . length($vertices) . " bytes (expected 48)");

    # GRADIENT_TRIANGLE structure (12 bytes):
    #   ULONG Vertex1 (4 bytes)
    #   ULONG Vertex2 (4 bytes)
    #   ULONG Vertex3 (4 bytes)
    # Pack format: "L L L"

    my $mesh = pack("L L L", 0, 1, 2);

    dbg("DrawGradientTriangle", "Mesh packed, length=" . length($mesh) . " bytes (expected 12)");

    # Call GradientFill
    my $ok = GradientFill($hdc, $vertices, 3, $mesh, 1, GRADIENT_FILL_TRIANGLE);
    dbg("DrawGradientTriangle", "GradientFill result=$ok");

    ReleaseDC($hwnd, $hdc);

    return $ok;
}

# Event handlers
sub Main_Terminate {
    dbg("Main_Terminate", "closing");
    return -1;
}

sub Main_Resize {
    dbg("Main_Resize", "redrawing");
    DrawGradientTriangle();
    return 1;
}

sub Main_Activate {
    dbg("Main_Activate", "redrawing");
    DrawGradientTriangle();
    return 1;
}

# Show and draw
$main->Show();
dbg("Main", "Window shown, handle=" . $main->{-handle});

# Draw after a short delay using DoEvents
for (1..10) {
    Win32::GUI::DoEvents();
    select(undef, undef, undef, 0.05);
}

dbg("Main", "Initial draw");
DrawGradientTriangle();

dbg("Main", "Entering message loop");
Win32::GUI::Dialog();
