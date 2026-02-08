use strict;
use warnings;
use Config;
use Win32::GUI();
use Win32::API;

my $width  = 640;
my $height = 480;

my $PTR_SIZE = $Config{ptrsize};
my $PTR_T = ($PTR_SIZE == 8) ? 'Q' : 'N';

sub pack_ptr {
    return pack($PTR_T, $_[0]);
}

sub unpack_ptr {
    return unpack($PTR_T, $_[0]);
}

# Win32 API
Win32::API->Import('user32', 'HDC GetDC(HWND hWnd)');
Win32::API->Import('user32', 'int ReleaseDC(HWND hWnd, HDC hDC)');

# GDI+ functions
my $GdiplusStartup  = Win32::API->new('gdiplus', 'GdiplusStartup',  'PPP', 'I');
my $GdiplusShutdown = Win32::API->new('gdiplus', 'GdiplusShutdown', $PTR_T, 'V');

my $GdipCreateFromHDC = Win32::API->new('gdiplus', 'GdipCreateFromHDC', $PTR_T . 'P', 'I');
my $GdipDeleteGraphics = Win32::API->new('gdiplus', 'GdipDeleteGraphics', $PTR_T, 'I');

my $GdipCreatePath = Win32::API->new('gdiplus', 'GdipCreatePath', 'IP', 'I');
my $GdipDeletePath = Win32::API->new('gdiplus', 'GdipDeletePath', $PTR_T, 'I');
my $GdipAddPathLine2I = Win32::API->new('gdiplus', 'GdipAddPathLine2I', $PTR_T . 'PI', 'I');
my $GdipClosePathFigure = Win32::API->new('gdiplus', 'GdipClosePathFigure', $PTR_T, 'I');

my $GdipCreatePathGradientFromPath = Win32::API->new('gdiplus', 'GdipCreatePathGradientFromPath', $PTR_T . 'P', 'I');
my $GdipSetPathGradientCenterColor = Win32::API->new('gdiplus', 'GdipSetPathGradientCenterColor', $PTR_T . 'N', 'I');
my $GdipSetPathGradientSurroundColorsWithCount = Win32::API->new('gdiplus', 'GdipSetPathGradientSurroundColorsWithCount', $PTR_T . 'PP', 'I');
my $GdipDeleteBrush = Win32::API->new('gdiplus', 'GdipDeleteBrush', $PTR_T, 'I');

my $GdipFillPath = Win32::API->new('gdiplus', 'GdipFillPath', $PTR_T . $PTR_T . $PTR_T, 'I');

my $gdip_token = 0;

sub gdiplus_startup {
    my $startup_input;
    if ($PTR_SIZE == 8) {
        $startup_input = pack('L x4 Q L L', 1, 0, 0, 0);
    } else {
        $startup_input = pack('L L L L', 1, 0, 0, 0);
    }

    my $token_buf = pack_ptr(0);
    my $status = $GdiplusStartup->Call($token_buf, $startup_input, 0);
    return (0, $status) if $status != 0;

    return (unpack_ptr($token_buf), 0);
}

sub gdiplus_shutdown {
    my ($token) = @_;
    return if $token == 0;
    $GdiplusShutdown->Call($token);
}

# Create main window
my $main = Win32::GUI::Window->new(
    -name   => 'Main',
    -text   => 'Perl Win32 GDI+ Triangle',
    -left   => 100,
    -top    => 100,
    -width  => $width,
    -height => $height,
);

sub DrawTriangle {
    my $hwnd = $main->{-handle};
    my $hdc = GetDC($hwnd);
    return 0 unless $hdc;

    my ($left, $top, $right, $bottom) = $main->GetClientRect();
    my $w = $right - $left;
    my $h = $bottom - $top;
    $w = $width if $w <= 0;
    $h = $height if $h <= 0;

    my $graphics_buf = pack_ptr(0);
    my $status = $GdipCreateFromHDC->Call($hdc, $graphics_buf);
    if ($status != 0) {
        ReleaseDC($hwnd, $hdc);
        return 0;
    }
    my $graphics = unpack_ptr($graphics_buf);

    my $path_buf = pack_ptr(0);
    $status = $GdipCreatePath->Call(0, $path_buf);
    if ($status != 0) {
        $GdipDeleteGraphics->Call($graphics);
        ReleaseDC($hwnd, $hdc);
        return 0;
    }
    my $path = unpack_ptr($path_buf);

    my @points = (
        int($w / 2), int($h / 4),
        int($w * 3 / 4), int($h * 3 / 4),
        int($w / 4), int($h * 3 / 4),
    );
    my $point_data = pack('l l l l l l', @points);

    $status = $GdipAddPathLine2I->Call($path, $point_data, 3);
    if ($status == 0) {
        $status = $GdipClosePathFigure->Call($path);
    }

    if ($status != 0) {
        $GdipDeletePath->Call($path);
        $GdipDeleteGraphics->Call($graphics);
        ReleaseDC($hwnd, $hdc);
        return 0;
    }

    my $brush_buf = pack_ptr(0);
    $status = $GdipCreatePathGradientFromPath->Call($path, $brush_buf);
    if ($status != 0) {
        $GdipDeletePath->Call($path);
        $GdipDeleteGraphics->Call($graphics);
        ReleaseDC($hwnd, $hdc);
        return 0;
    }
    my $brush = unpack_ptr($brush_buf);

    $GdipSetPathGradientCenterColor->Call($brush, 0xff555555);

    my $colors = pack('L3', 0xffff0000, 0xff00ff00, 0xff0000ff);
    my $count = pack('L', 3);
    $GdipSetPathGradientSurroundColorsWithCount->Call($brush, $colors, $count);

    $GdipFillPath->Call($graphics, $brush, $path);

    $GdipDeleteBrush->Call($brush);
    $GdipDeletePath->Call($path);
    $GdipDeleteGraphics->Call($graphics);
    ReleaseDC($hwnd, $hdc);

    return 1;
}

sub Main_Terminate {
    return -1;
}

sub Main_Resize {
    DrawTriangle();
    return 1;
}

sub Main_Activate {
    DrawTriangle();
    return 1;
}

my ($token, $startup_status) = gdiplus_startup();
if ($startup_status != 0) {
    die "GDI+ initialization failed: status=$startup_status\n";
}
$gdip_token = $token;

$main->Show();
for (1..10) {
    Win32::GUI::DoEvents();
    select(undef, undef, undef, 0.05);
}

DrawTriangle();
Win32::GUI::Dialog();

gdiplus_shutdown($gdip_token);
