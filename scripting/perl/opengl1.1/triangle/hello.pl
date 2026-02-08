use strict;
use warnings;
use Win32::API;
use Encode qw(encode);

print "=== Perl OpenGL 1.1 Triangle (Vertex Arrays) ===\n\n";

# ============================================================
# Constants
# ============================================================
use constant {
    # Window styles
    CS_OWNDC            => 0x0020,
    WS_OVERLAPPEDWINDOW => 0x00CF0000,
    CW_USEDEFAULT       => 0x80000000,
    SW_SHOW             => 5,
    
    # Messages
    WM_DESTROY => 0x0002,
    WM_CLOSE   => 0x0010,
    WM_QUIT    => 0x0012,
    PM_REMOVE  => 0x0001,
    
    # IDC/IDI
    IDI_APPLICATION => 32512,
    IDC_ARROW       => 32512,
    
    # Pixel Format Descriptor
    PFD_TYPE_RGBA       => 0,
    PFD_MAIN_PLANE      => 0,
    PFD_DRAW_TO_WINDOW  => 0x00000004,
    PFD_SUPPORT_OPENGL  => 0x00000020,
    PFD_DOUBLEBUFFER    => 0x00000001,
    
    # OpenGL 1.1
    GL_COLOR_BUFFER_BIT => 0x00004000,
    GL_FLOAT            => 0x1406,
    GL_TRIANGLE_STRIP   => 0x0005,
    GL_VERTEX_ARRAY     => 0x8074,
    GL_COLOR_ARRAY      => 0x8076,
};

# ============================================================
# Import Windows API functions
# ============================================================
my $GetModuleHandleW = Win32::API->new('kernel32', 'GetModuleHandleW', 'P', 'N');
my $GetLastError = Win32::API->new('kernel32', 'GetLastError', '', 'N');
my $Sleep = Win32::API->new('kernel32', 'Sleep', 'N', 'V');

my $RegisterClassExW = Win32::API->new('user32', 'RegisterClassExW', 'P', 'I');
my $CreateWindowExW = Win32::API->new('user32', 'CreateWindowExW', 'NPPNNNNNNNNP', 'N');
my $DefWindowProcW = Win32::API->new('user32', 'DefWindowProcW', 'NNNN', 'N');
my $LoadIconW = Win32::API->new('user32', 'LoadIconW', 'NN', 'N');
my $LoadCursorW = Win32::API->new('user32', 'LoadCursorW', 'NN', 'N');
my $ShowWindow = Win32::API->new('user32', 'ShowWindow', 'NN', 'I');
my $PeekMessageW = Win32::API->new('user32', 'PeekMessageW', 'PNNNN', 'I');
my $TranslateMessage = Win32::API->new('user32', 'TranslateMessage', 'P', 'I');
my $DispatchMessageW = Win32::API->new('user32', 'DispatchMessageW', 'P', 'N');
my $PostQuitMessage = Win32::API->new('user32', 'PostQuitMessage', 'N', 'V');
my $DestroyWindow = Win32::API->new('user32', 'DestroyWindow', 'N', 'I');
my $IsWindow = Win32::API->new('user32', 'IsWindow', 'N', 'I');
my $GetDC = Win32::API->new('user32', 'GetDC', 'N', 'N');
my $ReleaseDC = Win32::API->new('user32', 'ReleaseDC', 'NN', 'I');

my $ChoosePixelFormat = Win32::API->new('gdi32', 'ChoosePixelFormat', 'NP', 'I');
my $SetPixelFormat = Win32::API->new('gdi32', 'SetPixelFormat', 'NIP', 'I');
my $SwapBuffers = Win32::API->new('gdi32', 'SwapBuffers', 'N', 'I');

my $wglCreateContext = Win32::API->new('opengl32', 'wglCreateContext', 'N', 'N');
my $wglMakeCurrent = Win32::API->new('opengl32', 'wglMakeCurrent', 'NN', 'I');
my $wglDeleteContext = Win32::API->new('opengl32', 'wglDeleteContext', 'N', 'I');

my $glClearColor = Win32::API->new('opengl32', 'glClearColor', 'FFFF', 'V');
my $glClear = Win32::API->new('opengl32', 'glClear', 'N', 'V');

# OpenGL 1.1 Vertex Array functions
my $glEnableClientState = Win32::API->new('opengl32', 'glEnableClientState', 'N', 'V');
my $glDisableClientState = Win32::API->new('opengl32', 'glDisableClientState', 'N', 'V');
my $glColorPointer = Win32::API->new('opengl32', 'glColorPointer', 'IIIN', 'V');
my $glVertexPointer = Win32::API->new('opengl32', 'glVertexPointer', 'IIIN', 'V');
my $glDrawArrays = Win32::API->new('opengl32', 'glDrawArrays', 'NII', 'V');

# ============================================================
# Helper functions
# ============================================================
sub encode_utf16 {
    my ($str) = @_;
    my $utf16 = encode('UTF-16LE', $str);
    $utf16 .= "\0\0";
    return $utf16;
}

# ============================================================
# OpenGL initialization
# ============================================================
my $g_hdc = 0;
my $g_hrc = 0;

# Vertex data (global scope to keep in memory)
my $colors = pack('f9', 
    1.0, 0.0, 0.0,  # Red
    0.0, 1.0, 0.0,  # Green
    0.0, 0.0, 1.0   # Blue
);

my $vertices = pack('f6',
     0.0,  0.5,     # Top
     0.5, -0.5,     # Bottom-right
    -0.5, -0.5      # Bottom-left
);

sub enable_opengl {
    my ($hdc) = @_;
    
    # PIXELFORMATDESCRIPTOR structure (40 bytes on x64)
    my $pfd = pack('S S L C C C C C C C C C C C C C C C C C C L L L',
        40,                                 # nSize (WORD: 2 bytes)
        1,                                  # nVersion (WORD: 2 bytes)
        PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,  # dwFlags (DWORD: 4 bytes)
        PFD_TYPE_RGBA,                      # iPixelType (BYTE: 1 byte)
        24,                                 # cColorBits (BYTE: 1 byte)
        0, 0, 0, 0, 0, 0,                   # R/G/B bits and shifts (6 BYTEs)
        0, 0,                               # Alpha bits and shift (2 BYTEs)
        0, 0, 0, 0, 0,                      # Accum bits (5 BYTEs)
        16,                                 # cDepthBits (BYTE: 1 byte)
        0,                                  # cStencilBits (BYTE: 1 byte)
        0,                                  # cAuxBuffers (BYTE: 1 byte)
        PFD_MAIN_PLANE,                     # iLayerType (BYTE: 1 byte)
        0,                                  # bReserved (BYTE: 1 byte)
        0, 0, 0                             # Layer masks (3 DWORDs: 12 bytes)
    );
    
    my $fmt = $ChoosePixelFormat->Call($hdc, $pfd);
    unless ($fmt) {
        my $err = $GetLastError->Call();
        die "ChoosePixelFormat failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "Pixel format: $fmt\n";
    
    unless ($SetPixelFormat->Call($hdc, $fmt, $pfd)) {
        my $err = $GetLastError->Call();
        die "SetPixelFormat failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "SetPixelFormat succeeded\n";
    
    my $hrc = $wglCreateContext->Call($hdc);
    unless ($hrc) {
        my $err = $GetLastError->Call();
        die "wglCreateContext failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "OpenGL context created: 0x" . sprintf("%X", $hrc) . "\n";
    
    unless ($wglMakeCurrent->Call($hdc, $hrc)) {
        my $err = $GetLastError->Call();
        die "wglMakeCurrent failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "OpenGL context activated\n";
    
    return $hrc;
}

sub disable_opengl {
    my ($hwnd, $hdc, $hrc) = @_;
    
    if ($hrc) {
        $wglMakeCurrent->Call(0, 0);
        $wglDeleteContext->Call($hrc);
    }
    if ($hwnd && $hdc) {
        $ReleaseDC->Call($hwnd, $hdc);
    }
}

sub draw_triangle {
    # Enable client states
    $glEnableClientState->Call(GL_COLOR_ARRAY);
    $glEnableClientState->Call(GL_VERTEX_ARRAY);
    
    # Get pointers to data
    my $colors_ptr = unpack('Q', pack('P', $colors));
    my $vertices_ptr = unpack('Q', pack('P', $vertices));
    
    # Set pointers
    $glColorPointer->Call(3, GL_FLOAT, 0, $colors_ptr);
    $glVertexPointer->Call(2, GL_FLOAT, 0, $vertices_ptr);
    
    # Draw
    $glDrawArrays->Call(GL_TRIANGLE_STRIP, 0, 3);
    
    # Disable client states
    $glDisableClientState->Call(GL_VERTEX_ARRAY);
    $glDisableClientState->Call(GL_COLOR_ARRAY);
}

# ============================================================
# Main
# ============================================================
eval {
    print "Creating window...\n";
    
    my $hInstance = $GetModuleHandleW->Call(0);
    my $className = encode_utf16("PerlOpenGL11Class");
    
    my $hIcon = $LoadIconW->Call(0, IDI_APPLICATION);
    my $hCursor = $LoadCursorW->Call(0, IDC_ARROW);
    
    # Get DefWindowProcW and className addresses
    my $user32_dll = Win32::API->new('kernel32', 'LoadLibraryW', 'P', 'N');
    my $GetProcAddress = Win32::API->new('kernel32', 'GetProcAddress', 'NP', 'N');
    
    my $user32_handle = $user32_dll->Call(encode_utf16('user32.dll'));
    my $defproc_addr = $GetProcAddress->Call($user32_handle, "DefWindowProcW\0");
    
    unless ($defproc_addr) {
        die "Failed to get DefWindowProcW address\n";
    }
    
    print "DefWindowProcW address: 0x" . sprintf("%X", $defproc_addr) . "\n";
    
    use Win32::API::Type;
    my $className_ptr = unpack('Q', pack('P', $className));
    print "ClassName pointer: 0x" . sprintf("%X", $className_ptr) . "\n";
    
    my $wndclass = pack('L L Q l l Q Q Q Q Q Q Q',
        80,              # cbSize
        CS_OWNDC,        # style
        $defproc_addr,   # lpfnWndProc
        0,               # cbClsExtra
        0,               # cbWndExtra
        $hInstance,      # hInstance
        $hIcon,          # hIcon
        $hCursor,        # hCursor
        0,               # hbrBackground
        0,               # lpszMenuName
        $className_ptr,  # lpszClassName
        $hIcon           # hIconSm
    );
    
    my $atom = $RegisterClassExW->Call($wndclass);
    unless ($atom) {
        my $err = $GetLastError->Call();
        die "RegisterClassExW failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "Window class registered: atom = $atom\n";
    
    my $windowTitle = encode_utf16("OpenGL 1.1 Triangle (Perl)");
    
    my $hwnd = $CreateWindowExW->Call(
        0,                      # dwExStyle
        $className,             # lpClassName (pass string directly)
        $windowTitle,           # lpWindowName (pass string directly)
        WS_OVERLAPPEDWINDOW,    # dwStyle
        100,                    # x
        100,                    # y
        640,                    # width
        480,                    # height
        0,                      # hwndParent
        0,                      # hMenu
        $hInstance,             # hInstance
        0                       # lpParam
    );
    
    unless ($hwnd) {
        my $err = $GetLastError->Call();
        die "CreateWindowExW failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    
    print "Window created: 0x" . sprintf("%X", $hwnd) . "\n";
    
    $ShowWindow->Call($hwnd, SW_SHOW);
    
    $g_hdc = $GetDC->Call($hwnd);
    unless ($g_hdc) {
        my $err = $GetLastError->Call();
        die "GetDC failed: 0x" . sprintf("%08X", $err) . "\n";
    }
    print "Device context obtained: 0x" . sprintf("%X", $g_hdc) . "\n\n";
    
    print "Initializing OpenGL...\n";
    $g_hrc = enable_opengl($g_hdc);
    print "\n";
    
    print "Running render loop...\n";
    my $msg = "\0" x 48;  # MSG structure (48 bytes on x64)
    my $running = 1;
    
    while ($running) {
        # Check if window is still valid
        unless ($IsWindow->Call($hwnd)) {
            print "Window closed by user\n";
            $running = 0;
            last;
        }
        
        if ($PeekMessageW->Call($msg, 0, 0, 0, PM_REMOVE)) {
            my $msg_id = unpack('L', substr($msg, 8, 4));  # message field at offset 8
            if ($msg_id == WM_QUIT) {
                $running = 0;
            } elsif ($msg_id == WM_CLOSE || $msg_id == WM_DESTROY) {
                # Handle window close/destroy
                print "Received close message\n";
                $running = 0;
            } else {
                $TranslateMessage->Call($msg);
                $DispatchMessageW->Call($msg);
            }
        } else {
            # Render
            $glClearColor->Call(0.0, 0.0, 0.0, 0.0);
            $glClear->Call(GL_COLOR_BUFFER_BIT);
            
            draw_triangle();
            
            $SwapBuffers->Call($g_hdc);
            $Sleep->Call(1);
        }
    }
    
    print "Cleaning up...\n";
    disable_opengl($hwnd, $g_hdc, $g_hrc);
};

if ($@) {
    print "Error: $@\n";
}

print "Done.\n";
